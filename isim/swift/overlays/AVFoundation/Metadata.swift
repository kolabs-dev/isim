// isim AVFoundation metadata (self-authored, iOS API names): AVMetadataItem / AVMutableMetadataItem, identifiers,
// keys and key spaces, AVAsset.metadata / commonMetadata. Passthrough: the host's ffmpeg reads a file's metadata
// (ffmetadata) and writes items into movies (QuickTime "mdta" keys, iTunes / common tags). Items are text, numbers,
// dates and data; values are what ffmpeg reports (strings), converted for numberValue / dateValue.
import Foundation
import isim_host

public struct AVMetadataKeySpace: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let common = AVMetadataKeySpace("comn")
    public static let quickTimeUserData = AVMetadataKeySpace("udta")
    public static let quickTimeMetadata = AVMetadataKeySpace("mdta")
    public static let iTunes = AVMetadataKeySpace("itsk")
    public static let id3 = AVMetadataKeySpace("org.id3")
    public static let isoUserData = AVMetadataKeySpace("uiso")
}
public struct AVMetadataKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let commonKeyTitle = AVMetadataKey("title"), commonKeyCreator = AVMetadataKey("creator"), commonKeySubject = AVMetadataKey("subject")
    public static let commonKeyDescription = AVMetadataKey("description"), commonKeyPublisher = AVMetadataKey("publisher")
    public static let commonKeyContributor = AVMetadataKey("contributor"), commonKeyCreationDate = AVMetadataKey("creationDate")
    public static let commonKeyLastModifiedDate = AVMetadataKey("lastModifiedDate"), commonKeyType = AVMetadataKey("type")
    public static let commonKeyFormat = AVMetadataKey("format"), commonKeyIdentifier = AVMetadataKey("identifier"), commonKeySource = AVMetadataKey("source")
    public static let commonKeyLanguage = AVMetadataKey("language"), commonKeyRelation = AVMetadataKey("relation"), commonKeyLocation = AVMetadataKey("location")
    public static let commonKeyCopyrights = AVMetadataKey("copyrights"), commonKeyAlbumName = AVMetadataKey("albumName"), commonKeyAuthor = AVMetadataKey("author")
    public static let commonKeyArtist = AVMetadataKey("artist"), commonKeyArtwork = AVMetadataKey("artwork"), commonKeyMake = AVMetadataKey("make")
    public static let commonKeyModel = AVMetadataKey("model"), commonKeySoftware = AVMetadataKey("software")
    public static let quickTimeMetadataKeyContentIdentifier = AVMetadataKey("com.apple.quicktime.content.identifier")
    public static let quickTimeMetadataKeyLocationISO6709 = AVMetadataKey("com.apple.quicktime.location.ISO6709")
    public static let quickTimeMetadataKeyCreationDate = AVMetadataKey("com.apple.quicktime.creationdate")
    public static let quickTimeMetadataKeyTitle = AVMetadataKey("com.apple.quicktime.title")
    public static let quickTimeMetadataKeyDescription = AVMetadataKey("com.apple.quicktime.description")
    public static let quickTimeMetadataKeyMake = AVMetadataKey("com.apple.quicktime.make")
    public static let quickTimeMetadataKeyModel = AVMetadataKey("com.apple.quicktime.model")
    public static let quickTimeMetadataKeySoftware = AVMetadataKey("com.apple.quicktime.software")
    public static let quickTimeMetadataKeyArtist = AVMetadataKey("com.apple.quicktime.artist")
    public static let quickTimeMetadataKeyKeywords = AVMetadataKey("com.apple.quicktime.keywords")
    public static let quickTimeMetadataKeyComment = AVMetadataKey("com.apple.quicktime.comment")
}
public struct AVMetadataIdentifier: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    static func common(_ k: AVMetadataKey) -> AVMetadataIdentifier { AVMetadataIdentifier("common/" + k.rawValue) }
    public static let commonIdentifierTitle = common(.commonKeyTitle), commonIdentifierCreator = common(.commonKeyCreator)
    public static let commonIdentifierSubject = common(.commonKeySubject), commonIdentifierDescription = common(.commonKeyDescription)
    public static let commonIdentifierPublisher = common(.commonKeyPublisher), commonIdentifierCreationDate = common(.commonKeyCreationDate)
    public static let commonIdentifierLocation = common(.commonKeyLocation), commonIdentifierCopyrights = common(.commonKeyCopyrights)
    public static let commonIdentifierAlbumName = common(.commonKeyAlbumName), commonIdentifierAuthor = common(.commonKeyAuthor)
    public static let commonIdentifierArtist = common(.commonKeyArtist), commonIdentifierArtwork = common(.commonKeyArtwork)
    public static let commonIdentifierMake = common(.commonKeyMake), commonIdentifierModel = common(.commonKeyModel)
    public static let commonIdentifierSoftware = common(.commonKeySoftware), commonIdentifierType = common(.commonKeyType)
    public static let commonIdentifierLanguage = common(.commonKeyLanguage), commonIdentifierIdentifier = common(.commonKeyIdentifier)
    static func mdta(_ k: AVMetadataKey) -> AVMetadataIdentifier { AVMetadataIdentifier("mdta/" + k.rawValue) }
    public static let quickTimeMetadataContentIdentifier = mdta(.quickTimeMetadataKeyContentIdentifier)
    public static let quickTimeMetadataLocationISO6709 = mdta(.quickTimeMetadataKeyLocationISO6709)
    public static let quickTimeMetadataCreationDate = mdta(.quickTimeMetadataKeyCreationDate)
    public static let quickTimeMetadataTitle = mdta(.quickTimeMetadataKeyTitle)
    public static let quickTimeMetadataDescription = mdta(.quickTimeMetadataKeyDescription)
    public static let quickTimeMetadataMake = mdta(.quickTimeMetadataKeyMake)
    public static let quickTimeMetadataModel = mdta(.quickTimeMetadataKeyModel)
    public static let quickTimeMetadataSoftware = mdta(.quickTimeMetadataKeySoftware)
    public static let quickTimeMetadataArtist = mdta(.quickTimeMetadataKeyArtist)
    public static let quickTimeMetadataKeywords = mdta(.quickTimeMetadataKeyKeywords)
    public static let quickTimeMetadataComment = mdta(.quickTimeMetadataKeyComment)
}
public struct AVMetadataFormat: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let quickTimeMetadata = AVMetadataFormat(rawValue: "com.apple.quicktime.mdta")
    public static let quickTimeUserData = AVMetadataFormat(rawValue: "com.apple.quicktime.udta")
    public static let iTunesMetadata = AVMetadataFormat(rawValue: "com.apple.itunes")
    public static let id3Metadata = AVMetadataFormat(rawValue: "org.id3")
    public static let isoUserData = AVMetadataFormat(rawValue: "org.mp4ra")
}

open class AVMetadataItem: NSObject, NSCopying, NSMutableCopying, @unchecked Sendable {
    var _identifier: AVMetadataIdentifier?
    var _value: (NSCopying & NSObjectProtocol)?
    var _time = CMTime.invalid, _duration = CMTime.invalid
    var _locale: Locale?
    var _extendedLanguageTag: String?
    var _extra: [AVMetadataExtraAttributeKey: Any]?
    var _dataType: String?
    public override init() { super.init() }
    open var identifier: AVMetadataIdentifier? { _identifier }
    open var keySpace: AVMetadataKeySpace? { _identifier.flatMap { AVMetadataItem.keySpace(forIdentifier: $0) } }
    open var key: (NSCopying & NSObjectProtocol)? { _identifier.flatMap { AVMetadataItem.key(forIdentifier: $0) } }
    /// the common key an item maps to (common identifiers, and QuickTime / iTunes keys with a common meaning)
    open var commonKey: AVMetadataKey? {
        guard let id = _identifier else { return nil }
        if id.rawValue.hasPrefix("common/") { return AVMetadataKey(String(id.rawValue.dropFirst(7))) }
        return _MetadataMap.common[id.rawValue]
    }
    open var value: (NSCopying & NSObjectProtocol)? { _value }
    open var time: CMTime { _time }
    open var duration: CMTime { _duration }
    open var locale: Locale? { _locale }
    open var extendedLanguageTag: String? { _extendedLanguageTag }
    open var extraAttributes: [AVMetadataExtraAttributeKey: Any]? { _extra }
    open var dataType: String? { _dataType ?? (_value is NSString ? "com.apple.metadata.datatype.UTF-8" : _value is NSData ? "com.apple.metadata.datatype.raw-data" : nil) }
    open var startDate: Date? { nil }
    open var stringValue: String? {
        if let s = _value as? NSString { return s as String }
        if let n = _value as? NSNumber { return n.stringValue }
        if let d = _value as? NSDate { return ISO8601DateFormatter().string(from: d as Date) }
        return nil
    }
    open var numberValue: NSNumber? {
        if let n = _value as? NSNumber { return n }
        if let s = _value as? NSString, let d = Double(s as String) { return NSNumber(value: d) }
        return nil
    }
    open var dateValue: Date? {
        if let d = _value as? NSDate { return d as Date }
        if let s = _value as? NSString { return _MetadataMap.date(s as String) }
        return nil
    }
    open var dataValue: Data? {
        if let d = _value as? NSData { return d as Data }
        return (_value as? NSString).map { Data(($0 as String).utf8) }
    }
    open func copy(with zone: NSZone? = nil) -> Any { _copy(into: AVMetadataItem()) }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { _copy(into: AVMutableMetadataItem()) }
    func _copy<T: AVMetadataItem>(into o: T) -> T {
        o._identifier = _identifier; o._value = _value; o._time = _time; o._duration = _duration; o._locale = _locale
        o._extendedLanguageTag = _extendedLanguageTag; o._extra = _extra; o._dataType = _dataType
        return o
    }
    open class func metadataItems(from items: [AVMetadataItem], filteredByIdentifier identifier: AVMetadataIdentifier) -> [AVMetadataItem] {
        items.filter { $0.identifier == identifier }
    }
    open class func metadataItems(from items: [AVMetadataItem], withKey key: Any?, keySpace: AVMetadataKeySpace?) -> [AVMetadataItem] {
        let k = (key as? AVMetadataKey)?.rawValue ?? (key as? String)
        return items.filter { (k == nil || ($0.key as? NSString).map { $0 as String } == k || $0.commonKey?.rawValue == k) && (keySpace == nil || $0.keySpace == keySpace || (keySpace == .common && $0.commonKey != nil)) }
    }
    open class func metadataItems(from items: [AVMetadataItem], filteredAndSortedAccordingToPreferredLanguages languages: [String]) -> [AVMetadataItem] { items }
    open class func identifier(forKey key: Any, keySpace: AVMetadataKeySpace) -> AVMetadataIdentifier? {
        let k = (key as? AVMetadataKey)?.rawValue ?? (key as? String) ?? "\(key)"
        let space = keySpace == .common ? "common" : keySpace.rawValue
        return AVMetadataIdentifier(space + "/" + k)
    }
    open class func keySpace(forIdentifier identifier: AVMetadataIdentifier) -> AVMetadataKeySpace? {
        guard let slash = identifier.rawValue.firstIndex(of: "/") else { return nil }
        let s = String(identifier.rawValue[..<slash])
        return s == "common" ? .common : AVMetadataKeySpace(s)
    }
    open class func key(forIdentifier identifier: AVMetadataIdentifier) -> (NSCopying & NSObjectProtocol)? {
        guard let slash = identifier.rawValue.firstIndex(of: "/") else { return nil }
        return String(identifier.rawValue[identifier.rawValue.index(after: slash)...]) as NSString
    }
}
open class AVMutableMetadataItem: AVMetadataItem, @unchecked Sendable {
    public override init() { super.init() }
    open override var identifier: AVMetadataIdentifier? { get { _identifier } set { _identifier = newValue } }
    open override var keySpace: AVMetadataKeySpace? {
        get { super.keySpace }
        set { if let s = newValue, let k = key { _identifier = AVMetadataItem.identifier(forKey: k, keySpace: s) } }
    }
    open override var key: (NSCopying & NSObjectProtocol)? {
        get { super.key }
        set { if let k = newValue { _identifier = AVMetadataItem.identifier(forKey: k, keySpace: keySpace ?? .common) } }
    }
    open override var value: (NSCopying & NSObjectProtocol)? { get { _value } set { _value = newValue } }
    open override var time: CMTime { get { _time } set { _time = newValue } }
    open override var duration: CMTime { get { _duration } set { _duration = newValue } }
    open override var locale: Locale? { get { _locale } set { _locale = newValue } }
    open override var extendedLanguageTag: String? { get { _extendedLanguageTag } set { _extendedLanguageTag = newValue } }
    open override var extraAttributes: [AVMetadataExtraAttributeKey: Any]? { get { _extra } set { _extra = newValue } }
    open override var dataType: String? { get { super.dataType } set { _dataType = newValue } }
}
public struct AVMetadataExtraAttributeKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let info = AVMetadataExtraAttributeKey(rawValue: "info")
    public static let valueURI = AVMetadataExtraAttributeKey(rawValue: "valueURI")
    public static let baseURI = AVMetadataExtraAttributeKey(rawValue: "baseURI")
}

/// ffmpeg tag names <-> metadata identifiers
enum _MetadataMap {
    static let common: [String: AVMetadataKey] = [
        "mdta/com.apple.quicktime.title": .commonKeyTitle, "mdta/com.apple.quicktime.artist": .commonKeyArtist,
        "mdta/com.apple.quicktime.creationdate": .commonKeyCreationDate, "mdta/com.apple.quicktime.location.ISO6709": .commonKeyLocation,
        "mdta/com.apple.quicktime.make": .commonKeyMake, "mdta/com.apple.quicktime.model": .commonKeyModel,
        "mdta/com.apple.quicktime.software": .commonKeySoftware, "mdta/com.apple.quicktime.description": .commonKeyDescription,
        "udta/title": .commonKeyTitle, "udta/artist": .commonKeyArtist, "udta/comment": .commonKeyDescription, "udta/album": .commonKeyAlbumName,
        "udta/copyright": .commonKeyCopyrights, "udta/date": .commonKeyCreationDate, "udta/creation_time": .commonKeyCreationDate,
        "udta/location": .commonKeyLocation, "udta/encoder": .commonKeySoftware]
    /// common keys as ffmpeg's generic tag names
    static let ffmpegTag: [String: String] = ["title": "title", "artist": "artist", "creator": "artist", "author": "artist", "description": "comment",
        "albumName": "album", "copyrights": "copyright", "creationDate": "creation_time", "location": "location", "software": "encoder",
        "make": "com.apple.quicktime.make", "model": "com.apple.quicktime.model", "subject": "comment", "publisher": "publisher"]
    static func date(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        for p in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy"] { f.dateFormat = p; if let d = f.date(from: s) { return d } }
        return nil
    }
    /// the file's metadata tags (ffmpeg's ffmetadata dump)
    static func read(_ url: URL) -> [(String, String)] {
        let tmp = NSTemporaryDirectory() + "isim-meta-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        guard _FFmpeg.run(["-y", "-i", _path(url), "-map_metadata", "0", "-f", "ffmetadata", tmp]) == nil,
              let text = try? String(contentsOfFile: tmp, encoding: .utf8) else { return [] }
        var out: [(String, String)] = []
        for line in text.split(separator: "\n") where !line.hasPrefix(";") && !line.hasPrefix("[") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let k = String(line[..<eq]), v = String(line[line.index(after: eq)...]).replacingOccurrences(of: "\\=", with: "=")
            if ["major_brand", "minor_version", "compatible_brands"].contains(k) { continue }
            out.append((k, v))
        }
        return out
    }
    static func items(_ url: URL) -> [AVMetadataItem] {
        read(url).map { k, v in
            let item = AVMetadataItem()
            item._identifier = AVMetadataIdentifier(k.hasPrefix("com.apple.") ? "mdta/" + k : "udta/" + k)
            item._value = v as NSString
            return item
        }
    }
    /// ffmpeg arguments that write the items (QuickTime metadata keys need use_metadata_tags)
    static func arguments(_ items: [AVMetadataItem]) -> [String] {
        var a: [String] = []
        for i in items {
            guard let id = i.identifier, let v = i.stringValue ?? i.dateValue.map({ ISO8601DateFormatter().string(from: $0) }) else { continue }
            let space = id.rawValue.split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
            let key = (i.key as? NSString).map { $0 as String } ?? ""
            let tag = space == "common" ? (ffmpegTag[key] ?? key) : key
            guard !tag.isEmpty else { continue }
            a += ["-metadata", "\(tag)=\(v)"]
        }
        return a
    }
}

extension AVAsset {
    /// the asset's metadata (read with the host's ffmpeg; empty for compositions)
    public var metadata: [AVMetadataItem] { _url.map { _MetadataMap.items($0) } ?? [] }
    public var commonMetadata: [AVMetadataItem] { metadata.filter { $0.commonKey != nil } }
    public var availableMetadataFormats: [AVMetadataFormat] {
        let m = metadata
        var f: [AVMetadataFormat] = []
        if m.contains(where: { $0.keySpace == .quickTimeMetadata }) { f.append(.quickTimeMetadata) }
        if m.contains(where: { $0.keySpace == .quickTimeUserData }) { f.append(.quickTimeUserData) }
        return f
    }
    public func metadata(forFormat format: AVMetadataFormat) -> [AVMetadataItem] {
        metadata.filter { format == .quickTimeMetadata ? $0.keySpace == .quickTimeMetadata : $0.keySpace == .quickTimeUserData }
    }
}
