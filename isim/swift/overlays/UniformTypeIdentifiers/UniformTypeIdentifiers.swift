// isim UniformTypeIdentifiers (self-authored, iOS API names): UTType with the system types (isim's table: conformance,
// filename extensions, MIME types) and the app's Info.plist type declarations (UTExportedTypeDeclarations /
// UTImportedTypeDeclarations, read on first use); UTTypeReference, the Objective-C `UTType` class (headers in
// sdk-src/Frameworks/UniformTypeIdentifiers); plus NSItemProvider (Foundation on iOS; isim keeps it here
// next to the type system it needs — apps get it through PhotosUI or `import UniformTypeIdentifiers`).
import Foundation

public struct UTType: Hashable, Sendable, CustomStringConvertible, Codable {
    public let identifier: String
    let parents: [String]
    let exts: [String]
    let mimes: [String]
    let dynamic: Bool
    let desc: String?
    let refURL: URL?
    let ver: Int?

    init(_ id: String, _ parents: [String], ext: [String] = [], mime: [String] = [], dynamic: Bool = false, description: String? = nil,
         referenceURL: URL? = nil, version: Int? = nil) {
        identifier = id; self.parents = parents; exts = ext; mimes = mime; self.dynamic = dynamic; desc = description; refURL = referenceURL; ver = version
    }
    public init?(_ identifier: String) {
        if let t = UTType.known[identifier] { self = t } else { self.init(identifier, ["public.data"], dynamic: false) }
    }
    public init?(filenameExtension: String) { self.init(filenameExtension: filenameExtension, conformingTo: .data) }
    public init?(filenameExtension: String, conformingTo supertype: UTType) {
        let e = filenameExtension.lowercased()
        if let t = UTType.searchOrder.first(where: { $0.exts.contains(e) && $0.conforms(to: supertype) }) { self = t }
        else { self.init("dyn.isim-ext-\(e)", [supertype.identifier], ext: [e], dynamic: true) }
    }
    public init?(mimeType: String) { self.init(mimeType: mimeType, conformingTo: .data) }
    public init?(mimeType: String, conformingTo supertype: UTType) {
        let m = mimeType.lowercased()
        guard let t = UTType.searchOrder.first(where: { $0.mimes.contains(m) && $0.conforms(to: supertype) }) else { return nil }
        self = t
    }
    /// the app's own type: as its Info.plist declares it (UTExportedTypeDeclarations), else just conforming to `parentType`
    public init(exportedAs identifier: String, conformingTo parentType: UTType? = nil) {
        if let t = UTType.exported[identifier] ?? UTType.builtin[identifier] { self = t }
        else { self.init(identifier, [parentType?.identifier ?? "public.data"]) }
    }
    /// another app's type: as this app's Info.plist imports it (UTImportedTypeDeclarations; the owner's own declaration
    /// would win on iOS), else just conforming to `parentType`
    public init(importedAs identifier: String, conformingTo parentType: UTType? = nil) {
        if let t = UTType.known[identifier] { self = t }
        else { self.init(identifier, [parentType?.identifier ?? "public.data"]) }
    }

    public var preferredFilenameExtension: String? { exts.first }
    public var preferredMIMEType: String? { mimes.first }
    public var tags: [UTTagClass: [String]] {
        var t: [UTTagClass: [String]] = [:]
        if !exts.isEmpty { t[.filenameExtension] = exts }
        if !mimes.isEmpty { t[.mimeType] = mimes }
        return t
    }
    /// isim: `tags` before it took Apple's type (keyed by tag class): apps built with older isim releases call this
    /// under the old symbol (an alias, buildlib/swift.py)
    public var _isimTagsV1: [String: [String]] { ["public.filename-extension": exts, "public.mime-type": mimes] }
    public var isDynamic: Bool { dynamic }
    /// declared by the system or by the app's Info.plist
    public var isDeclared: Bool { UTType.known[identifier] != nil }
    public var isPublicType: Bool { identifier.hasPrefix("public.") }
    public var isSystemDeclared: Bool { UTType.builtin[identifier] != nil }
    public var localizedDescription: String? { desc ?? UTType.known[identifier]?.desc ?? (dynamic ? nil : identifier) }
    public var referenceURL: URL? { refURL ?? UTType.known[identifier]?.refURL }
    public var version: Int? { ver ?? UTType.known[identifier]?.ver }
    public var description: String { identifier }
    public var supertypes: Set<UTType> {
        var out = Set<UTType>(), todo = parents
        while let p = todo.popLast() {
            let t = UTType.known[p] ?? UTType(p, [])
            if out.insert(t).inserted { todo += t.parents }
        }
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
    public static let plainText = UTType("public.plain-text", ["public.text"], ext: ["txt", "text"], mime: ["text/plain"])
    public static let utf8PlainText = UTType("public.utf8-plain-text", ["public.plain-text"])
    public static let utf16PlainText = UTType("public.utf16-plain-text", ["public.plain-text"])
    public static let utf16ExternalPlainText = UTType("public.utf16-external-plain-text", ["public.plain-text"])
    public static let utf8TabSeparatedText = UTType("public.utf8-tab-separated-values-text", ["public.tab-separated-values-text", "public.utf8-plain-text"])
    public static let delimitedText = UTType("public.delimited-values-text", ["public.text"])
    public static let commaSeparatedText = UTType("public.comma-separated-values-text", ["public.delimited-values-text"], ext: ["csv"], mime: ["text/csv", "text/comma-separated-values"])
    public static let tabSeparatedText = UTType("public.tab-separated-values-text", ["public.delimited-values-text"], ext: ["tsv"], mime: ["text/tab-separated-values"])
    public static let rtf = UTType("public.rtf", ["public.text"], ext: ["rtf"], mime: ["text/rtf", "application/rtf"])
    public static let rtfd = UTType("com.apple.rtfd", ["com.apple.package", "public.composite-content"], ext: ["rtfd"])
    public static let flatRTFD = UTType("com.apple.flat-rtfd", ["public.data", "public.composite-content"])
    public static let html = UTType("public.html", ["public.text"], ext: ["html", "htm", "shtml"], mime: ["text/html"])
    public static let xml = UTType("public.xml", ["public.text"], ext: ["xml"], mime: ["application/xml", "text/xml"])
    public static let yaml = UTType("public.yaml", ["public.text"], ext: ["yaml", "yml"], mime: ["application/x-yaml", "application/yaml"])
    public static let markdown = UTType("net.daringfireball.markdown", ["public.plain-text"], ext: ["md", "markdown"], mime: ["text/markdown"])
    public static let css = UTType("public.css", ["public.text"], ext: ["css"], mime: ["text/css"])
    public static let log = UTType("com.apple.log", ["public.plain-text"], ext: ["log"])
    public static let sourceCode = UTType("public.source-code", ["public.plain-text"])
    public static let assemblyLanguageSource = UTType("public.assembly-source", ["public.source-code"], ext: ["s"])
    public static let cSource = UTType("public.c-source", ["public.source-code"], ext: ["c"])
    public static let objectiveCSource = UTType("public.objective-c-source", ["public.source-code"], ext: ["m"])
    public static let swiftSource = UTType("public.swift-source", ["public.source-code"], ext: ["swift"])
    public static let cPlusPlusSource = UTType("public.c-plus-plus-source", ["public.source-code"], ext: ["cpp", "cc", "cxx", "c++", "cp"])
    public static let objectiveCPlusPlusSource = UTType("public.objective-c-plus-plus-source", ["public.source-code"], ext: ["mm"])
    public static let cHeader = UTType("public.c-header", ["public.source-code"], ext: ["h"])
    public static let cPlusPlusHeader = UTType("public.c-plus-plus-header", ["public.source-code"], ext: ["hpp", "hh", "hxx", "h++"])
    public static let script = UTType("public.script", ["public.source-code"])
    public static let appleScript = UTType("com.apple.applescript.text", ["public.script"], ext: ["applescript"])
    public static let osaScript = UTType("com.apple.applescript.script", ["public.data", "public.script"], ext: ["scpt"])
    public static let osaScriptBundle = UTType("com.apple.applescript.script-bundle", ["com.apple.bundle", "com.apple.package", "public.script"], ext: ["scptd"])
    public static let javaScript = UTType("com.netscape.javascript-source", ["public.script"], ext: ["js", "jscript", "javascript", "mjs"], mime: ["text/javascript", "application/javascript"])
    public static let shellScript = UTType("public.shell-script", ["public.script"], ext: ["sh", "command"], mime: ["application/x-sh"])
    public static let perlScript = UTType("public.perl-script", ["public.shell-script"], ext: ["pl", "pm"], mime: ["text/x-perl-script"])
    public static let pythonScript = UTType("public.python-script", ["public.shell-script"], ext: ["py"], mime: ["text/x-python-script"])
    public static let rubyScript = UTType("public.ruby-script", ["public.shell-script"], ext: ["rb", "rbw"], mime: ["text/ruby-script"])
    public static let phpScript = UTType("public.php-script", ["public.shell-script"], ext: ["php", "php3", "php4", "ph3", "ph4", "phtml"], mime: ["text/php"])
    public static let makefile = UTType("public.make-source", ["public.script"])
    public static let json = UTType("public.json", ["public.text"], ext: ["json"], mime: ["application/json"])
    public static let geoJSON = UTType("public.geojson", ["public.json"], ext: ["geojson"], mime: ["application/geo+json"])
    public static let propertyList = UTType("com.apple.property-list", ["public.data"], ext: ["plist"])
    public static let xmlPropertyList = UTType("com.apple.xml-property-list", ["public.xml", "com.apple.property-list"])
    public static let binaryPropertyList = UTType("com.apple.binary-property-list", ["com.apple.property-list"])
    public static let pdf = UTType("com.adobe.pdf", ["public.data", "public.composite-content"], ext: ["pdf"], mime: ["application/pdf"])
    public static let epub = UTType("org.idpf.epub-container", ["public.data", "public.composite-content"], ext: ["epub"], mime: ["application/epub+zip"])
    public static let spreadsheet = UTType("public.spreadsheet", ["public.content"])
    public static let presentation = UTType("public.presentation", ["public.composite-content"])
    public static let database = UTType("public.database", ["public.data"])
    public static let url = UTType("public.url", ["public.data"])
    public static let fileURL = UTType("public.file-url", ["public.url"])
    public static let urlBookmarkData = UTType("com.apple.bookmark", ["public.data"])
    public static let bookmark = UTType("public.bookmark", ["public.data"])
    public static let internetLocation = UTType("com.apple.internet-location", ["public.data"], ext: ["inetloc"])
    public static let internetShortcut = UTType("com.microsoft.internet-shortcut", ["public.data"], ext: ["url"])
    public static let webArchive = UTType("com.apple.webarchive", ["public.data", "public.composite-content"], ext: ["webarchive"], mime: ["application/x-webarchive"])
    public static let linkPresentationMetadata = UTType("com.apple.linkpresentation.metadata", ["public.data"])
    public static let vCard = UTType("public.vcard", ["public.text", "public.contact"], ext: ["vcf", "vcard"], mime: ["text/vcard", "text/x-vcard"])
    public static let toDoItem = UTType("public.to-do-item", ["public.item"])
    public static let calendarEvent = UTType("public.calendar-event", ["public.item"])
    public static let emailMessage = UTType("public.email-message", ["public.data"], ext: ["eml"], mime: ["message/rfc822"])
    public static let message = UTType("public.message", ["public.data"])
    public static let contact = UTType("public.contact", ["public.item"])
    public static let image = UTType("public.image", ["public.data", "public.content"])
    public static let png = UTType("public.png", ["public.image"], ext: ["png"], mime: ["image/png"])
    public static let jpeg = UTType("public.jpeg", ["public.image"], ext: ["jpeg", "jpg", "jpe"], mime: ["image/jpeg", "image/jpg"])
    public static let heic = UTType("public.heic", ["public.heif-standard", "public.image"], ext: ["heic"], mime: ["image/heic"])
    public static let heics = UTType("public.heics", ["public.heif-standard", "public.image"], ext: ["heics"], mime: ["image/heic-sequence"])
    public static let heif = UTType("public.heif", ["public.heif-standard", "public.image"], ext: ["heif"], mime: ["image/heif"])
    public static let jpegxl = UTType("public.jpeg-xl", ["public.image"], ext: ["jxl"], mime: ["image/jxl"])
    public static let gif = UTType("com.compuserve.gif", ["public.image"], ext: ["gif"], mime: ["image/gif"])
    public static let tiff = UTType("public.tiff", ["public.image"], ext: ["tiff", "tif"], mime: ["image/tiff"])
    public static let bmp = UTType("com.microsoft.bmp", ["public.image"], ext: ["bmp"], mime: ["image/bmp"])
    public static let ico = UTType("com.microsoft.ico", ["public.image"], ext: ["ico"], mime: ["image/vnd.microsoft.icon", "image/x-icon"])
    public static let icns = UTType("com.apple.icns", ["public.image"], ext: ["icns"])
    public static let svg = UTType("public.svg-image", ["public.image"], ext: ["svg"], mime: ["image/svg+xml"])
    public static let webP = UTType("org.webmproject.webp", ["public.image"], ext: ["webp"], mime: ["image/webp"])
    public static let rawImage = UTType("public.camera-raw-image", ["public.image"])
    public static let dng = UTType("com.adobe.raw-image", ["public.camera-raw-image"], ext: ["dng"], mime: ["image/x-adobe-dng"])
    public static let exr = UTType("com.ilm.openexr-image", ["public.image"], ext: ["exr"], mime: ["image/x-exr"])
    public static let livePhoto = UTType("com.apple.live-photo", ["public.data"])
    public static let threeDContent = UTType("public.3d-content", ["public.content"])
    public static let usd = UTType("com.pixar.universal-scene-description", ["public.3d-content", "public.data"], ext: ["usd", "usda", "usdc"])
    public static let usdz = UTType("com.pixar.universal-scene-description-mobile", ["public.3d-content", "public.data"], ext: ["usdz"], mime: ["model/vnd.usdz+zip"])
    public static let realityFile = UTType("com.apple.reality", ["public.data"], ext: ["reality"])
    public static let sceneKitScene = UTType("com.apple.scenekit.scene", ["public.3d-content", "public.data"], ext: ["scn"])
    public static let arReferenceObject = UTType("com.apple.arobject", ["public.data"], ext: ["arobject"])
    public static let audiovisualContent = UTType("public.audiovisual-content", ["public.data", "public.content"])
    public static let movie = UTType("public.movie", ["public.audiovisual-content"])
    public static let video = UTType("public.video", ["public.movie"])
    public static let quickTimeMovie = UTType("com.apple.quicktime-movie", ["public.movie"], ext: ["mov", "qt"], mime: ["video/quicktime"])
    public static let mpeg = UTType("public.mpeg", ["public.movie"], ext: ["mpg", "mpeg", "mpe", "m75", "m15"], mime: ["video/mpeg", "video/mpg"])
    public static let mpeg2Video = UTType("public.mpeg-2-video", ["public.movie"], ext: ["m2v"], mime: ["video/mpeg2"])
    public static let mpeg2TransportStream = UTType("public.mpeg-2-transport-stream", ["public.movie"], ext: ["ts"], mime: ["video/mp2t"])
    public static let mpeg4Movie = UTType("public.mpeg-4", ["public.movie"], ext: ["mp4", "mpeg4"], mime: ["video/mp4", "video/mp4v"])
    public static let appleProtectedMPEG4Video = UTType("com.apple.protected-mpeg-4-video", ["public.movie"], ext: ["m4v"])
    public static let avi = UTType("public.avi", ["public.movie"], ext: ["avi", "vfw"], mime: ["video/avi", "video/msvideo", "video/x-msvideo"])
    public static let audio = UTType("public.audio", ["public.audiovisual-content"])
    public static let mp3 = UTType("public.mp3", ["public.audio"], ext: ["mp3"], mime: ["audio/mpeg", "audio/mp3"])
    public static let mpeg4Audio = UTType("public.mpeg-4-audio", ["public.audio"], ext: ["m4a"], mime: ["audio/mp4", "audio/m4a"])
    public static let appleProtectedMPEG4Audio = UTType("com.apple.protected-mpeg-4-audio", ["public.audio"], ext: ["m4p"])
    public static let wav = UTType("com.microsoft.waveform-audio", ["public.audio"], ext: ["wav", "wave"], mime: ["audio/wav", "audio/vnd.wave", "audio/x-wav"])
    public static let aiff = UTType("public.aiff-audio", ["public.audio"], ext: ["aiff", "aif"], mime: ["audio/aiff", "audio/x-aiff"])
    public static let midi = UTType("public.midi-audio", ["public.audio"], ext: ["mid", "midi", "smf", "kar"], mime: ["audio/midi", "audio/x-midi"])
    public static let playlist = UTType("public.playlist", [])
    public static let m3uPlaylist = UTType("public.m3u-playlist", ["public.text", "public.playlist"], ext: ["m3u", "m3u8"], mime: ["audio/mpegurl", "audio/x-mpegurl"])
    public static let ahap = UTType("com.apple.haptics.ahap", ["public.json"], ext: ["ahap"])
    public static let folder = UTType("public.folder", ["public.directory"])
    public static let volume = UTType("public.volume", ["public.folder"])
    public static let mountPoint = UTType("com.apple.mount-point", ["public.folder"])
    public static let directory = UTType("public.directory", ["public.item"])
    public static let package = UTType("com.apple.package", ["public.directory"])
    public static let bundle = UTType("com.apple.bundle", ["public.directory"])
    public static let symbolicLink = UTType("public.symlink", ["public.item"])
    public static let aliasFile = UTType("com.apple.alias-file", ["public.data"])
    public static let resolvable = UTType("com.apple.resolvable", [])
    public static let executable = UTType("public.executable", ["public.item"])
    public static let unixExecutable = UTType("public.unix-executable", ["public.data", "public.executable"])
    public static let exe = UTType("com.microsoft.windows-executable", ["public.data", "public.executable"], ext: ["exe"])
    public static let application = UTType("com.apple.application", ["public.executable"])
    public static let applicationBundle = UTType("com.apple.application-bundle", ["com.apple.application", "com.apple.bundle", "com.apple.package"], ext: ["app"])
    public static let applicationExtension = UTType("com.apple.application-and-system-extension", ["com.apple.bundle", "com.apple.package"], ext: ["appex"])
    public static let framework = UTType("com.apple.framework", ["com.apple.bundle"], ext: ["framework"])
    public static let pluginBundle = UTType("com.apple.plugin", ["com.apple.bundle", "com.apple.package"], ext: ["plugin"])
    public static let spotlightImporter = UTType("com.apple.metadata-importer", ["com.apple.plugin"], ext: ["mdimporter"])
    public static let quickLookGenerator = UTType("com.apple.quicklook-generator", ["com.apple.plugin"], ext: ["qlgenerator"])
    public static let xpcService = UTType("com.apple.xpc-service", ["com.apple.bundle", "com.apple.package"], ext: ["xpc"])
    public static let systemPreferencesPane = UTType("com.apple.systempreference.prefpane", ["com.apple.package", "com.apple.bundle"], ext: ["prefpane"])
    public static let archive = UTType("public.archive", ["public.data"])
    public static let gzip = UTType("org.gnu.gnu-zip-archive", ["public.data", "public.archive"], ext: ["gz", "gzip"], mime: ["application/x-gzip", "application/gzip"])
    public static let bz2 = UTType("public.bzip2-archive", ["public.data", "public.archive"], ext: ["bz2", "bzip2"], mime: ["application/x-bzip2"])
    public static let zip = UTType("public.zip-archive", ["public.data", "public.archive"], ext: ["zip"], mime: ["application/zip", "application/x-zip-compressed"])
    public static let appleArchive = UTType("com.apple.archive", ["public.data", "public.archive"], ext: ["aar"])
    public static let tarArchive = UTType("public.tar-archive", ["public.data", "public.archive"], ext: ["tar"], mime: ["application/x-tar", "application/tar"])
    public static let diskImage = UTType("public.disk-image", ["public.data", "public.archive"])
    public static let font = UTType("public.font", ["public.data"])
    public static let pkcs12 = UTType("com.rsa.pkcs-12", ["public.data"], ext: ["p12", "pfx"], mime: ["application/x-pkcs12"])
    public static let x509Certificate = UTType("public.x509-certificate", ["public.data"], ext: ["cer", "crt", "der"], mime: ["application/x-x509-ca-cert"])
    public static let shazamSignature = UTType("com.shazam.signature", ["public.data"], ext: ["shazamsignature"])
    public static let shazamCustomCatalog = UTType("com.shazam.custom-catalog", ["public.data"], ext: ["shazamcatalog"])

    /// the system's types (isim's table)
    static let builtinList: [UTType] = [item, content, data, compositeContent, text, plainText, utf8PlainText, utf16PlainText, utf16ExternalPlainText,
        utf8TabSeparatedText, delimitedText, commaSeparatedText, tabSeparatedText, rtf, rtfd, flatRTFD, html, xml, yaml, markdown, css, log, sourceCode,
        assemblyLanguageSource, cSource, objectiveCSource, swiftSource, cPlusPlusSource, objectiveCPlusPlusSource, cHeader, cPlusPlusHeader, script,
        appleScript, osaScript, osaScriptBundle, javaScript, shellScript, perlScript, pythonScript, rubyScript, phpScript, makefile, json, geoJSON,
        propertyList, xmlPropertyList, binaryPropertyList, pdf, epub, spreadsheet, presentation, database, url, fileURL, urlBookmarkData, bookmark,
        internetLocation, internetShortcut, webArchive, linkPresentationMetadata, vCard, toDoItem, calendarEvent, emailMessage, message, contact,
        image, png, jpeg, heic, heics, heif, jpegxl, gif, tiff, bmp, ico, icns, svg, webP, rawImage, dng, exr, livePhoto, threeDContent, usd, usdz,
        realityFile, sceneKitScene, arReferenceObject, audiovisualContent, movie, video, quickTimeMovie, mpeg, mpeg2Video, mpeg2TransportStream,
        mpeg4Movie, appleProtectedMPEG4Video, avi, audio, mp3, mpeg4Audio, appleProtectedMPEG4Audio, wav, aiff, midi, playlist, m3uPlaylist, ahap,
        folder, volume, mountPoint, directory, package, bundle, symbolicLink, aliasFile, resolvable, executable, unixExecutable, exe, application,
        applicationBundle, applicationExtension, framework, pluginBundle, spotlightImporter, quickLookGenerator, xpcService, systemPreferencesPane,
        archive, gzip, bz2, zip, appleArchive, tarArchive, diskImage, font, pkcs12, x509Certificate, shazamSignature, shazamCustomCatalog,
        UTType("public.heif-standard", ["public.image"])]
    static let builtin: [String: UTType] = Dictionary(builtinList.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })

    /// a declaration of the app's Info.plist (UTExportedTypeDeclarations / UTImportedTypeDeclarations)
    static func declared(_ key: String) -> [UTType] {
        guard let decls = Bundle.main.object(forInfoDictionaryKey: key) as? [[String: Any]] else { return [] }
        func strings(_ v: Any?) -> [String] { (v as? [String]) ?? (v as? String).map { [$0] } ?? [] }
        return decls.compactMap { d in
            guard let id = d["UTTypeIdentifier"] as? String, !id.isEmpty else { return nil }
            let spec = d["UTTypeTagSpecification"] as? [String: Any] ?? [:]
            let version = (d["UTTypeVersion"] as? String).flatMap { Int($0) } ?? d["UTTypeVersion"] as? Int
            return UTType(id, strings(d["UTTypeConformsTo"]), ext: strings(spec["public.filename-extension"]).map { $0.lowercased() },
                          mime: strings(spec["public.mime-type"]).map { $0.lowercased() }, description: d["UTTypeDescription"] as? String,
                          referenceURL: (d["UTTypeReferenceURL"] as? String).flatMap(URL.init(string:)), version: version)
        }
    }
    static let exportedList = declared("UTExportedTypeDeclarations")
    static let importedList = declared("UTImportedTypeDeclarations")
    static let exported: [String: UTType] = Dictionary(exportedList.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })
    /// every declared type: the system's, then the app's exported, then its imported ones
    static let known: [String: UTType] = {
        var k = builtin
        for t in exportedList + importedList where k[t.identifier] == nil { k[t.identifier] = t }
        return k
    }()
    /// for extension and MIME lookups: the app's exported types first, then the system's, then imported ones
    static let searchOrder: [UTType] = exportedList + builtinList + importedList

    public static func types(tag: String, tagClass: UTTagClass, conformingTo supertype: UTType?) -> [UTType] {
        let t = tag.lowercased()
        return searchOrder.filter { (tagClass == .filenameExtension ? $0.exts : $0.mimes).contains(t) && (supertype.map($0.conforms(to:)) ?? true) }
    }
}

/// UTType as an Objective-C object (Apple's `UTType` class): what UniformTypeIdentifiers.framework's headers declare.
@objc(UTType)
public final class UTTypeReference: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    let _type: UTType
    init(_ t: UTType) { _type = t }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(_type.identifier as NSString, forKey: "identifier") }
    public init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "identifier") as String?, let t = UTType(id) else { return nil }
        _type = t
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
    public override func isEqual(_ object: Any?) -> Bool { (object as? UTTypeReference)?._type == _type }
    public override var hash: Int { _type.hashValue }
    public override var description: String { _type.identifier }

    @objc(typeWithIdentifier:) public class func type(withIdentifier identifier: String) -> UTTypeReference? { UTType(identifier).map(UTTypeReference.init) }
    @objc(typeWithFilenameExtension:) public class func type(withFilenameExtension ext: String) -> UTTypeReference? {
        UTType(filenameExtension: ext).map(UTTypeReference.init)
    }
    @objc(typeWithFilenameExtension:conformingToType:) public class func type(withFilenameExtension ext: String, conformingTo supertype: UTTypeReference) -> UTTypeReference? {
        UTType(filenameExtension: ext, conformingTo: supertype._type).map(UTTypeReference.init)
    }
    @objc(typeWithMIMEType:) public class func type(withMIMEType mime: String) -> UTTypeReference? { UTType(mimeType: mime).map(UTTypeReference.init) }
    @objc(typeWithMIMEType:conformingToType:) public class func type(withMIMEType mime: String, conformingTo supertype: UTTypeReference) -> UTTypeReference? {
        UTType(mimeType: mime, conformingTo: supertype._type).map(UTTypeReference.init)
    }
    @objc(exportedTypeWithIdentifier:) public class func exportedType(withIdentifier identifier: String) -> UTTypeReference {
        UTTypeReference(UTType(exportedAs: identifier))
    }
    @objc(exportedTypeWithIdentifier:conformingToType:) public class func exportedType(withIdentifier identifier: String, conformingTo parent: UTTypeReference) -> UTTypeReference {
        UTTypeReference(UTType(exportedAs: identifier, conformingTo: parent._type))
    }
    @objc(importedTypeWithIdentifier:) public class func importedType(withIdentifier identifier: String) -> UTTypeReference {
        UTTypeReference(UTType(importedAs: identifier))
    }
    @objc(importedTypeWithIdentifier:conformingToType:) public class func importedType(withIdentifier identifier: String, conformingTo parent: UTTypeReference) -> UTTypeReference {
        UTTypeReference(UTType(importedAs: identifier, conformingTo: parent._type))
    }
    @objc(typesWithTag:tagClass:conformingToType:) public class func types(withTag tag: String, tagClass: String, conformingTo supertype: UTTypeReference?) -> [UTTypeReference] {
        UTType.types(tag: tag, tagClass: UTTagClass(rawValue: tagClass), conformingTo: supertype?._type).map(UTTypeReference.init)
    }
    @objc public var identifier: String { _type.identifier }
    @objc public var preferredFilenameExtension: String? { _type.preferredFilenameExtension }
    @objc(preferredMIMEType) public var preferredMIMEType: String? { _type.preferredMIMEType }
    @objc public var localizedDescription: String? { _type.localizedDescription }
    @objc public var version: NSNumber? { _type.version.map { NSNumber(value: $0) } }
    @objc public var referenceURL: URL? { _type.referenceURL }
    @objc(isDynamic) public var isDynamic: Bool { _type.isDynamic }
    @objc(isDeclared) public var isDeclared: Bool { _type.isDeclared }
    @objc(isPublicType) public var isPublicType: Bool { _type.isPublicType }
    @objc public var tags: [String: [String]] { Dictionary(uniqueKeysWithValues: _type.tags.map { ($0.key.rawValue, $0.value) }) }
    @objc public var supertypes: Set<UTTypeReference> { Set(_type.supertypes.map(UTTypeReference.init)) }
    @objc(conformsToType:) public func conforms(to type: UTTypeReference) -> Bool { _type.conforms(to: type._type) }
    @objc(isSupertypeOfType:) public func isSupertype(of type: UTTypeReference) -> Bool { _type.isSupertype(of: type._type) }
    @objc(isSubtypeOfType:) public func isSubtype(of type: UTTypeReference) -> Bool { _type.isSubtype(of: type._type) }
}
extension UTType: CustomDebugStringConvertible {
    /// Foundation's ReferenceConvertible pairing: the Objective-C class UTType bridges to
    public typealias ReferenceType = UTTypeReference
    public var debugDescription: String { identifier }
}
extension UTType: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> UTTypeReference { UTTypeReference(self) }
    public static func _forceBridgeFromObjectiveC(_ source: UTTypeReference, result: inout UTType?) { result = source._type }
    public static func _conditionallyBridgeFromObjectiveC(_ source: UTTypeReference, result: inout UTType?) -> Bool { result = source._type; return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ source: UTTypeReference?) -> UTType { source?._type ?? .data }
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

extension URLResourceValues {
    /// the file's type (from its filename extension; directories are folders)
    public var contentType: UTType? { (allValues[.contentTypeKey] as? String ?? typeIdentifier).flatMap { UTType($0) } }
}
