// isim MusicKit (self-authored, iOS API names): authorization, music items (Song, Album, Artist, Playlist, Track),
// collections, library requests, catalog search / resource / data requests, the subscription and the music players.
// - The library is isim's simulated music library (MediaPlayer's: $ISIM_DATA/Media/Music), behind the same
//   permission as MPMediaLibrary (NSAppleMusicUsageDescription).
// - Catalog requests are passthrough to the Apple Music API: they need a developer token, which iOS gets for a
//   registered app and isim cannot: set ISIM_MUSICKIT_DEVELOPER_TOKEN (and optionally ISIM_MUSICKIT_USER_TOKEN,
//   ISIM_MUSICKIT_STOREFRONT, default "us"). Without it they throw MusicTokenRequestError.developerTokenRequestFailed.
//   ISIM_MUSICKIT_API replaces https://api.music.apple.com (tests use a local server).
// - There is no Apple Music subscription on isim: catalog songs cannot be played (adapted, like a device without
//   one); library songs play through MediaPlayer's players.
@_exported import Foundation
import Combine
import MediaPlayer
import CoreGraphics

// MARK: - authorization

public enum MusicAuthorization {
    public enum Status: String, Equatable, Hashable, Sendable, CustomStringConvertible {
        case notDetermined, denied, restricted, authorized
        public var description: String { rawValue }
    }
    public static var currentStatus: Status { status(MPMediaLibrary.authorizationStatus()) }
    public static func request() async -> Status { status(await MPMediaLibrary.requestAuthorization()) }
    static func status(_ s: MPMediaLibraryAuthorizationStatus) -> Status {
        switch s { case .authorized: return .authorized; case .denied: return .denied; case .restricted: return .restricted; default: return .notDetermined }
    }
}

// MARK: - identifiers and items

public struct MusicItemID: Equatable, Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public var description: String { rawValue }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public protocol MusicItem: Identifiable, Hashable, Sendable where ID == MusicItemID {}
public protocol MusicCatalogSearchable: MusicItem { static var _searchType: String { get } }
public protocol FilterableMusicItem: MusicItem { associatedtype FilterType }
public protocol MusicLibraryRequestable: MusicItem { associatedtype LibraryFilter }
public protocol PlayableMusicItem: MusicItem { var playParameters: PlayParameters? { get } }
public protocol MusicPropertyContainer {}

public struct PlayParameters: Equatable, Hashable, Sendable, Codable {
    public let id: MusicItemID
    public let kind: String
    let library: Bool
    init(id: MusicItemID, kind: String, library: Bool) { self.id = id; self.kind = kind; self.library = library }
}

/// Artwork: library artwork is written to a file; catalog artwork is an Apple Music URL template.
public struct Artwork: Equatable, Hashable, Sendable {
    let template: String
    public let maximumWidth: Int
    public let maximumHeight: Int
    public var backgroundColor: CGColor? { nil }
    public func url(width: Int, height: Int) -> URL? {
        URL(string: template.replacingOccurrences(of: "{w}", with: "\(width)").replacingOccurrences(of: "{h}", with: "\(height)"))
    }
}

/// a property set relationships are named by in with(_:) (relationships are loaded together with the item)
public struct MusicPropertySet: Sendable {}
public final class PartialMusicProperty<Root>: Sendable {
    let name: String
    init(_ name: String) { self.name = name }
}

public struct Song: MusicItem, MusicCatalogSearchable, FilterableMusicItem, MusicLibraryRequestable, PlayableMusicItem, MusicPropertyContainer, Codable {
    public typealias FilterType = Song
    public typealias LibraryFilter = Song
    public static var _searchType: String { "songs" }
    public let id: MusicItemID
    public let title: String
    public let artistName: String
    public let albumTitle: String?
    public let duration: TimeInterval?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let genreNames: [String]
    public let composerName: String?
    public let releaseDate: Date?
    public let isrc: String?
    public let url: URL?
    public let hasLyrics: Bool
    public let playCount: Int?
    public let lastPlayedDate: Date?
    public let libraryAddedDate: Date?
    public let artwork: Artwork?
    public let playParameters: PlayParameters?
    public static let albums = PartialMusicProperty<Song>("albums"), artists = PartialMusicProperty<Song>("artists")
    var _library: Bool { playParameters?.library ?? false }
    /// the loaded relationships (library: the song's album and artist)
    public var albums: MusicItemCollection<Album>? { _library ? MusicItemCollection(_Library.albums().filter { $0.title == albumTitle }) : nil }
    public var artists: MusicItemCollection<Artist>? { _library ? MusicItemCollection(_Library.artists().filter { $0.name == artistName }) : nil }
    public func with(_ properties: [PartialMusicProperty<Song>]) async throws -> Song { self }
    public static func == (a: Song, b: Song) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
    private enum CodingKeys: String, CodingKey { case id, title, artistName, albumTitle, duration, trackNumber, genreNames, isrc, url }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(MusicItemID.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        artistName = try c.decodeIfPresent(String.self, forKey: .artistName) ?? ""
        albumTitle = try c.decodeIfPresent(String.self, forKey: .albumTitle); duration = try c.decodeIfPresent(Double.self, forKey: .duration)
        trackNumber = try c.decodeIfPresent(Int.self, forKey: .trackNumber); genreNames = try c.decodeIfPresent([String].self, forKey: .genreNames) ?? []
        isrc = try c.decodeIfPresent(String.self, forKey: .isrc); url = try c.decodeIfPresent(URL.self, forKey: .url)
        discNumber = nil; composerName = nil; releaseDate = nil; hasLyrics = false; playCount = nil; lastPlayedDate = nil; libraryAddedDate = nil; artwork = nil
        playParameters = PlayParameters(id: id, kind: "song", library: false)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(title, forKey: .title); try c.encode(artistName, forKey: .artistName)
        try c.encodeIfPresent(albumTitle, forKey: .albumTitle); try c.encodeIfPresent(duration, forKey: .duration)
        try c.encodeIfPresent(trackNumber, forKey: .trackNumber); try c.encode(genreNames, forKey: .genreNames)
        try c.encodeIfPresent(isrc, forKey: .isrc); try c.encodeIfPresent(url, forKey: .url)
    }
    init(id: MusicItemID, title: String, artistName: String, albumTitle: String?, duration: TimeInterval?, trackNumber: Int?, genreNames: [String],
         composerName: String?, releaseDate: Date?, isrc: String?, url: URL?, playCount: Int?, lastPlayedDate: Date?, libraryAddedDate: Date?,
         artwork: Artwork?, library: Bool) {
        self.id = id; self.title = title; self.artistName = artistName; self.albumTitle = albumTitle; self.duration = duration
        self.trackNumber = trackNumber; discNumber = trackNumber == nil ? nil : 1; self.genreNames = genreNames; self.composerName = composerName
        self.releaseDate = releaseDate; self.isrc = isrc; self.url = url; hasLyrics = false; self.playCount = playCount
        self.lastPlayedDate = lastPlayedDate; self.libraryAddedDate = libraryAddedDate; self.artwork = artwork
        playParameters = PlayParameters(id: id, kind: "song", library: library)
    }
}

public struct Album: MusicItem, MusicCatalogSearchable, FilterableMusicItem, MusicLibraryRequestable, PlayableMusicItem, MusicPropertyContainer {
    public typealias FilterType = Album
    public typealias LibraryFilter = Album
    public static var _searchType: String { "albums" }
    public let id: MusicItemID
    public let title: String
    public let artistName: String
    public let trackCount: Int
    public let releaseDate: Date?
    public let genreNames: [String]
    public let isCompilation: Bool?
    public let url: URL?
    public let artwork: Artwork?
    public let playParameters: PlayParameters?
    let _tracks: [Song]
    public var tracks: MusicItemCollection<Track>? { _tracks.isEmpty ? nil : MusicItemCollection(_tracks.map { Track.song($0) }) }
    public static let tracks = PartialMusicProperty<Album>("tracks"), artists = PartialMusicProperty<Album>("artists")
    public func with(_ properties: [PartialMusicProperty<Album>]) async throws -> Album { self }
    public static func == (a: Album, b: Album) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

public struct Artist: MusicItem, MusicCatalogSearchable, FilterableMusicItem, MusicLibraryRequestable, MusicPropertyContainer {
    public typealias FilterType = Artist
    public typealias LibraryFilter = Artist
    public static var _searchType: String { "artists" }
    public let id: MusicItemID
    public let name: String
    public let genreNames: [String]?
    public let url: URL?
    public let artwork: Artwork?
    let _albums: [Album]
    public var albums: MusicItemCollection<Album>? { _albums.isEmpty ? nil : MusicItemCollection(_albums) }
    public static let albums = PartialMusicProperty<Artist>("albums")
    public func with(_ properties: [PartialMusicProperty<Artist>]) async throws -> Artist { self }
    public static func == (a: Artist, b: Artist) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

public struct Playlist: MusicItem, MusicCatalogSearchable, FilterableMusicItem, MusicLibraryRequestable, PlayableMusicItem, MusicPropertyContainer {
    public typealias FilterType = Playlist
    public typealias LibraryFilter = Playlist
    public static var _searchType: String { "playlists" }
    public enum Kind: String, Sendable { case editorial, external, personalMix, replay, userShared }
    public let id: MusicItemID
    public let name: String
    public let curatorName: String?
    public let standardDescription: String?
    public let lastModifiedDate: Date?
    public let kind: Kind?
    public let url: URL?
    public let artwork: Artwork?
    public let playParameters: PlayParameters?
    let _tracks: [Song]
    public var tracks: MusicItemCollection<Track>? { MusicItemCollection(_tracks.map { Track.song($0) }) }
    public static let tracks = PartialMusicProperty<Playlist>("tracks"), entries = PartialMusicProperty<Playlist>("entries")
    public func with(_ properties: [PartialMusicProperty<Playlist>]) async throws -> Playlist { self }
    public static func == (a: Playlist, b: Playlist) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

/// A track of an album or playlist (songs; isim has no music videos).
public enum Track: MusicItem, PlayableMusicItem, MusicPropertyContainer {
    case song(Song)
    public var id: MusicItemID { if case .song(let s) = self { return s.id }; return "" }
    public var title: String { if case .song(let s) = self { return s.title }; return "" }
    public var artistName: String { if case .song(let s) = self { return s.artistName }; return "" }
    public var albumTitle: String? { if case .song(let s) = self { return s.albumTitle }; return nil }
    public var duration: TimeInterval? { if case .song(let s) = self { return s.duration }; return nil }
    public var trackNumber: Int? { if case .song(let s) = self { return s.trackNumber }; return nil }
    public var artwork: Artwork? { if case .song(let s) = self { return s.artwork }; return nil }
    public var playParameters: PlayParameters? { if case .song(let s) = self { return s.playParameters }; return nil }
}

public struct MusicItemCollection<MusicItemType: MusicItem>: RandomAccessCollection, Hashable, Sendable, ExpressibleByArrayLiteral, CustomStringConvertible {
    let items: [MusicItemType]
    public let title: String?
    public init<S: Sequence>(_ items: S) where S.Element == MusicItemType { self.items = Array(items); title = nil }
    public init(arrayLiteral elements: MusicItemType...) { items = elements; title = nil }
    public var startIndex: Int { items.startIndex }
    public var endIndex: Int { items.endIndex }
    public subscript(i: Int) -> MusicItemType { items[i] }
    public var hasNextBatch: Bool { false }
    public func nextBatch(limit: Int? = nil) async throws -> MusicItemCollection<MusicItemType>? { nil }
    public var description: String { "MusicItemCollection<\(MusicItemType.self)>(\(items.count) items)" }
}

// MARK: - the library

enum _Library {
    static var authorized: Bool { MPMediaLibrary.authorizationStatus() == .authorized }
    static func id(_ pid: MPMediaEntityPersistentID, _ kind: String) -> MusicItemID { MusicItemID("i.\(kind).\(pid)") }
    static func artwork(_ item: MPMediaItem) -> Artwork? {
        guard let a = item.artwork, let img = a.image(at: CGSize(width: 600, height: 600)), let png = img.pngData() else { return nil }
        let path = NSTemporaryDirectory() + "musickit-artwork-\(item.persistentID).png"
        if !FileManager.default.fileExists(atPath: path) { try? png.write(to: URL(fileURLWithPath: path)) }
        return Artwork(template: URL(fileURLWithPath: path).absoluteString, maximumWidth: 600, maximumHeight: 600)
    }
    static func song(_ i: MPMediaItem) -> Song {
        Song(id: id(i.persistentID, "song"), title: i.title ?? "", artistName: i.artist ?? "", albumTitle: i.albumTitle, duration: i.playbackDuration,
             trackNumber: i.albumTrackNumber > 0 ? i.albumTrackNumber : nil, genreNames: i.genre.map { [$0] } ?? [], composerName: i.composer,
             releaseDate: i.releaseDate, isrc: nil, url: nil, playCount: i.playCount, lastPlayedDate: i.lastPlayedDate, libraryAddedDate: i.dateAdded,
             artwork: artwork(i), library: true)
    }
    static func items() -> [MPMediaItem] { MPMediaQuery.songs().items ?? [] }
    static func songs() -> [Song] { items().map(song) }
    static func albums() -> [Album] {
        (MPMediaQuery.albums().collections ?? []).map { c in
            let r = c.representativeItem
            let tracks = c.items.map(song)
            return Album(id: id(r?.albumPersistentID ?? 0, "album"), title: r?.albumTitle ?? "", artistName: r?.albumArtist ?? r?.artist ?? "",
                         trackCount: c.count, releaseDate: r?.releaseDate, genreNames: r?.genre.map { [$0] } ?? [], isCompilation: false, url: nil,
                         artwork: r.flatMap(artwork), playParameters: PlayParameters(id: id(r?.albumPersistentID ?? 0, "album"), kind: "album", library: true), _tracks: tracks)
        }
    }
    static func artists() -> [Artist] {
        let albums = albums()
        return (MPMediaQuery.artists().collections ?? []).map { c in
            let name = c.representativeItem?.artist ?? ""
            return Artist(id: id(c.representativeItem?.artistPersistentID ?? 0, "artist"), name: name, genreNames: nil, url: nil, artwork: nil,
                          _albums: albums.filter { $0.artistName == name })
        }
    }
    static func playlists() -> [Playlist] {
        (MPMediaQuery.playlists().collections ?? []).compactMap { $0 as? MPMediaPlaylist }.map { p in
            Playlist(id: id(p.persistentID, "playlist"), name: p.name ?? "", curatorName: p.authorDisplayName, standardDescription: p.descriptionText,
                     lastModifiedDate: nil, kind: nil, url: nil, artwork: nil,
                     playParameters: PlayParameters(id: id(p.persistentID, "playlist"), kind: "playlist", library: true), _tracks: p.items.map(song))
        }
    }
    static func all<T>(_ t: T.Type) -> [T] {
        if T.self == Song.self { return songs() as! [T] }
        if T.self == Album.self { return albums() as! [T] }
        if T.self == Artist.self { return artists() as! [T] }
        if T.self == Playlist.self { return playlists() as! [T] }
        return []
    }
    static func mediaItem(_ s: Song) -> MPMediaItem? { items().first { id($0.persistentID, "song") == s.id } }
}

/// iOS 16: items of the user's library, filtered and sorted.
public struct MusicLibraryRequest<MusicItemType: MusicLibraryRequestable> {
    public var limit: Int = 0
    public var offset: Int = 0
    var filters: [(MusicItemType) -> Bool] = []
    var sorts: [(MusicItemType, MusicItemType) -> Bool] = []
    public init() {}
    public mutating func filter<Value: Equatable>(matching keyPath: KeyPath<MusicItemType.LibraryFilter, Value>, equalTo value: Value) {
        filters.append { ($0 as? MusicItemType.LibraryFilter)?[keyPath: keyPath] == value }
    }
    public mutating func filter<Value: Equatable>(matching keyPath: KeyPath<MusicItemType.LibraryFilter, Value>, memberOf values: [Value]) {
        filters.append { ($0 as? MusicItemType.LibraryFilter).map { values.contains($0[keyPath: keyPath]) } ?? false }
    }
    public mutating func filter(matching keyPath: KeyPath<MusicItemType.LibraryFilter, String>, contains text: String) {
        filters.append { ($0 as? MusicItemType.LibraryFilter)?[keyPath: keyPath].localizedCaseInsensitiveContains(text) ?? false }
    }
    public mutating func filter(matching keyPath: KeyPath<MusicItemType.LibraryFilter, String?>, contains text: String) {
        filters.append { ($0 as? MusicItemType.LibraryFilter)?[keyPath: keyPath]?.localizedCaseInsensitiveContains(text) ?? false }
    }
    public mutating func sort<Value: Comparable>(by keyPath: KeyPath<MusicItemType, Value>, ascending: Bool) {
        sorts.append { ascending ? $0[keyPath: keyPath] < $1[keyPath: keyPath] : $0[keyPath: keyPath] > $1[keyPath: keyPath] }
    }
    public mutating func sort<Value: Comparable>(by keyPath: KeyPath<MusicItemType, Value?>, ascending: Bool) {
        sorts.append { a, b in
            guard let x = a[keyPath: keyPath], let y = b[keyPath: keyPath] else { return a[keyPath: keyPath] != nil }
            return ascending ? x < y : x > y
        }
    }
    public func response() async throws -> MusicLibraryResponse<MusicItemType> {
        guard _Library.authorized else { throw MusicDataRequest.Error(status: 403, code: "40300", title: "Forbidden", detailText: "music library access was not authorized") }
        // library items render their artwork: UIKit work, on the main thread
        let all = await MainActor.run { _Library.all(MusicItemType.self) }
        var items = all.filter { i in filters.allSatisfy { $0(i) } }
        for s in sorts.reversed() { items = items.enumerated().sorted { s($0.element, $1.element) || (!s($1.element, $0.element) && $0.offset < $1.offset) }.map(\.element) }
        items = Array(items.dropFirst(offset))
        if limit > 0 { items = Array(items.prefix(limit)) }
        return MusicLibraryResponse(items: MusicItemCollection(items))
    }
}
public struct MusicLibraryResponse<MusicItemType: MusicItem>: Sendable {
    public let items: MusicItemCollection<MusicItemType>
}
/// iOS 16: add catalog items to the library (not possible without an Apple Music subscription, adapted)
public final class MusicLibrary: @unchecked Sendable {
    public static let shared = MusicLibrary()
    public func add<T: MusicItem>(_ item: T) async throws { throw MPError(.cloudServiceCapabilityMissing) }
    public func createPlaylist(name: String, description: String? = nil, authorDisplayName: String? = nil, items: [Song] = []) async throws -> Playlist {
        let p = try await MPMediaLibrary.default().getPlaylist(with: UUID(), creationMetadata: {
            let m = MPMediaPlaylistCreationMetadata(name: name); m.descriptionText = description ?? ""; m.authorDisplayName = authorDisplayName; return m
        }())
        try await p.add(items.compactMap(_Library.mediaItem))
        let lists = await MainActor.run { _Library.playlists() }
        return lists.first { $0.id == _Library.id(p.persistentID, "playlist") }
            ?? Playlist(id: _Library.id(p.persistentID, "playlist"), name: name, curatorName: authorDisplayName, standardDescription: description,
                        lastModifiedDate: Date(), kind: nil, url: nil, artwork: nil, playParameters: nil, _tracks: items)
    }
}

// MARK: - the catalog (Apple Music API)

public enum MusicTokenRequestError: Error, Equatable, Sendable, CustomStringConvertible {
    case unknown, permissionDenied, privacyAcknowledgementRequired, userNotSignedIn, userTokenRevoked, developerTokenRequestFailed, userTokenRequestFailed
    public var description: String {
        self == .developerTokenRequestFailed ? "developerTokenRequestFailed (isim cannot obtain a MusicKit developer token: set ISIM_MUSICKIT_DEVELOPER_TOKEN)" : "\(self)"
    }
}
enum _AppleMusicAPI {
    static var env: [String: String] { ProcessInfo.processInfo.environment }
    static var base: String { env["ISIM_MUSICKIT_API"] ?? "https://api.music.apple.com" }
    static var storefront: String { env["ISIM_MUSICKIT_STOREFRONT"] ?? "us" }
    static func authorize(_ r: inout URLRequest) throws {
        guard let token = env["ISIM_MUSICKIT_DEVELOPER_TOKEN"], !token.isEmpty else { throw MusicTokenRequestError.developerTokenRequestFailed }
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let user = env["ISIM_MUSICKIT_USER_TOKEN"], !user.isEmpty { r.setValue(user, forHTTPHeaderField: "Music-User-Token") }
    }
    static func get(_ path: String, _ query: [URLQueryItem] = []) async throws -> [String: Any] {
        var c = URLComponents(string: base + path)!
        if !query.isEmpty { c.queryItems = query }
        var r = URLRequest(url: c.url!)
        try authorize(&r)
        let (data, response) = try await URLSession.shared.data(for: r)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let e = (json["errors"] as? [[String: Any]])?.first
            throw MusicDataRequest.Error(status: status, code: e?["code"] as? String ?? "\(status)", title: e?["title"] as? String ?? "", detailText: e?["detail"] as? String ?? "")
        }
        return json
    }
    static func date(_ s: Any?) -> Date? {
        guard let s = s as? String else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = s.count == 4 ? "yyyy" : "yyyy-MM-dd"
        return f.date(from: s)
    }
    static func artwork(_ a: Any?) -> Artwork? {
        guard let a = a as? [String: Any], let u = a["url"] as? String else { return nil }
        return Artwork(template: u, maximumWidth: a["width"] as? Int ?? 0, maximumHeight: a["height"] as? Int ?? 0)
    }
    static func song(_ r: [String: Any]) -> Song {
        let a = r["attributes"] as? [String: Any] ?? [:]
        return Song(id: MusicItemID(r["id"] as? String ?? ""), title: a["name"] as? String ?? "", artistName: a["artistName"] as? String ?? "",
                    albumTitle: a["albumName"] as? String, duration: (a["durationInMillis"] as? Double).map { $0 / 1000 },
                    trackNumber: a["trackNumber"] as? Int, genreNames: a["genreNames"] as? [String] ?? [], composerName: a["composerName"] as? String,
                    releaseDate: date(a["releaseDate"]), isrc: a["isrc"] as? String, url: (a["url"] as? String).flatMap(URL.init(string:)),
                    playCount: nil, lastPlayedDate: nil, libraryAddedDate: nil, artwork: artwork(a["artwork"]), library: false)
    }
    static func album(_ r: [String: Any]) -> Album {
        let a = r["attributes"] as? [String: Any] ?? [:]
        let tracks = (((r["relationships"] as? [String: Any])?["tracks"] as? [String: Any])?["data"] as? [[String: Any]] ?? []).map(song)
        let id = MusicItemID(r["id"] as? String ?? "")
        return Album(id: id, title: a["name"] as? String ?? "", artistName: a["artistName"] as? String ?? "", trackCount: a["trackCount"] as? Int ?? tracks.count,
                     releaseDate: date(a["releaseDate"]), genreNames: a["genreNames"] as? [String] ?? [], isCompilation: a["isCompilation"] as? Bool,
                     url: (a["url"] as? String).flatMap(URL.init(string:)), artwork: artwork(a["artwork"]),
                     playParameters: PlayParameters(id: id, kind: "album", library: false), _tracks: tracks)
    }
    static func artist(_ r: [String: Any]) -> Artist {
        let a = r["attributes"] as? [String: Any] ?? [:]
        return Artist(id: MusicItemID(r["id"] as? String ?? ""), name: a["name"] as? String ?? "", genreNames: a["genreNames"] as? [String],
                      url: (a["url"] as? String).flatMap(URL.init(string:)), artwork: artwork(a["artwork"]), _albums: [])
    }
    static func playlist(_ r: [String: Any]) -> Playlist {
        let a = r["attributes"] as? [String: Any] ?? [:]
        let id = MusicItemID(r["id"] as? String ?? "")
        return Playlist(id: id, name: a["name"] as? String ?? "", curatorName: a["curatorName"] as? String,
                        standardDescription: (a["description"] as? [String: Any])?["standard"] as? String, lastModifiedDate: date(a["lastModifiedDate"]),
                        kind: (a["playlistType"] as? String).flatMap { Playlist.Kind(rawValue: $0 == "editorial" ? "editorial" : $0) },
                        url: (a["url"] as? String).flatMap(URL.init(string:)), artwork: artwork(a["artwork"]),
                        playParameters: PlayParameters(id: id, kind: "playlist", library: false), _tracks: [])
    }
    static func items<T>(_ data: [[String: Any]], _ t: T.Type) -> [T] {
        if T.self == Song.self { return data.map(song) as! [T] }
        if T.self == Album.self { return data.map(album) as! [T] }
        if T.self == Artist.self { return data.map(artist) as! [T] }
        if T.self == Playlist.self { return data.map(playlist) as! [T] }
        return []
    }
}

public struct MusicCatalogSearchRequest {
    public var term: String
    public var types: [any MusicCatalogSearchable.Type]
    public var limit: Int?
    public var offset: Int?
    public var includeTopResults = false
    public init(term: String, types: [any MusicCatalogSearchable.Type]) { self.term = term; self.types = types }
    public func response() async throws -> MusicCatalogSearchResponse {
        var q = [URLQueryItem(name: "term", value: term), URLQueryItem(name: "types", value: types.map { $0._searchType }.joined(separator: ","))]
        if let limit { q.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let offset { q.append(URLQueryItem(name: "offset", value: "\(offset)")) }
        let json = try await _AppleMusicAPI.get("/v1/catalog/\(_AppleMusicAPI.storefront)/search", q)
        let results = json["results"] as? [String: Any] ?? [:]
        func data(_ k: String) -> [[String: Any]] { (results[k] as? [String: Any])?["data"] as? [[String: Any]] ?? [] }
        return MusicCatalogSearchResponse(songs: MusicItemCollection(data("songs").map(_AppleMusicAPI.song)),
                                          albums: MusicItemCollection(data("albums").map(_AppleMusicAPI.album)),
                                          artists: MusicItemCollection(data("artists").map(_AppleMusicAPI.artist)),
                                          playlists: MusicItemCollection(data("playlists").map(_AppleMusicAPI.playlist)))
    }
}
public struct MusicCatalogSearchResponse: Sendable {
    public let songs: MusicItemCollection<Song>
    public let albums: MusicItemCollection<Album>
    public let artists: MusicItemCollection<Artist>
    public let playlists: MusicItemCollection<Playlist>
}
public struct MusicCatalogResourceRequest<MusicItemType: FilterableMusicItem> {
    let ids: [String]
    public var limit: Int?
    public var properties: [PartialMusicProperty<MusicItemType>] = []
    public init<Value>(matching keyPath: KeyPath<MusicItemType.FilterType, Value>, equalTo value: Value) { ids = ["\(value)"] }
    public init<Value>(matching keyPath: KeyPath<MusicItemType.FilterType, Value>, memberOf values: [Value]) { ids = values.map { "\($0)" } }
    public func response() async throws -> MusicCatalogResourceResponse<MusicItemType> {
        let kind = (MusicItemType.self as? any MusicCatalogSearchable.Type)?._searchType ?? "songs"
        let json = try await _AppleMusicAPI.get("/v1/catalog/\(_AppleMusicAPI.storefront)/\(kind)", [URLQueryItem(name: "ids", value: ids.joined(separator: ","))])
        let items = _AppleMusicAPI.items(json["data"] as? [[String: Any]] ?? [], MusicItemType.self)
        return MusicCatalogResourceResponse(items: MusicItemCollection(limit.map { Array(items.prefix($0)) } ?? items))
    }
}
public struct MusicCatalogResourceResponse<MusicItemType: MusicItem>: Sendable {
    public let items: MusicItemCollection<MusicItemType>
}
/// A request to any Apple Music API endpoint, with the developer (and user) token added.
public struct MusicDataRequest {
    public struct Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        public let status: Int
        public let code: String
        public let title: String
        public let detailText: String
        public var description: String { "MusicDataRequest.Error(status: \(status), code: \(code), title: \(title), detailText: \(detailText))" }
    }
    public let urlRequest: URLRequest
    public init(urlRequest: URLRequest) { self.urlRequest = urlRequest }
    public func response() async throws -> MusicDataResponse {
        var r = urlRequest
        if let u = r.url, u.host == "api.music.apple.com", let base = URL(string: _AppleMusicAPI.base), base.host != u.host {
            var c = URLComponents(url: u, resolvingAgainstBaseURL: false)!
            c.scheme = base.scheme; c.host = base.host; c.port = base.port
            r.url = c.url
        }
        try _AppleMusicAPI.authorize(&r)
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw Error(status: 0, code: "0", title: "No response", detailText: "") }
        if !(200..<300).contains(http.statusCode) { throw Error(status: http.statusCode, code: "\(http.statusCode)", title: HTTPURLResponse.localizedString(forStatusCode: http.statusCode), detailText: "") }
        return MusicDataResponse(data: data, urlResponse: http)
    }
}
public struct MusicDataResponse: Sendable {
    public let data: Data
    public let urlResponse: HTTPURLResponse
}

/// The user's Apple Music subscription: none on isim.
public struct MusicSubscription: Equatable, Hashable, Sendable {
    public let canPlayCatalogContent: Bool
    public let canBecomeSubscriber: Bool
    public let hasCloudLibraryEnabled: Bool
    public static var current: MusicSubscription { get async throws { MusicSubscription(canPlayCatalogContent: false, canBecomeSubscriber: false, hasCloudLibraryEnabled: false) } }
    public static var subscriptionUpdates: AsyncStream<MusicSubscription> {
        AsyncStream { c in c.yield(MusicSubscription(canPlayCatalogContent: false, canBecomeSubscriber: false, hasCloudLibraryEnabled: false)) }
    }
}

// MARK: - players

public class MusicPlayer: @unchecked Sendable {
    public enum PlaybackStatus: Equatable, Hashable, Sendable { case stopped, playing, paused, interrupted, seekingForward, seekingBackward }
    public enum RepeatMode: Equatable, Hashable, Sendable { case none, one, all }
    public enum ShuffleMode: Equatable, Hashable, Sendable { case off, songs }
    /// playback state (observable)
    public final class State: ObservableObject, @unchecked Sendable {
        @Published public internal(set) var playbackStatus: PlaybackStatus = .stopped
        @Published public var playbackRate: Float = 0
        @Published public var repeatMode: RepeatMode? { didSet { _player?._apply() } }
        @Published public var shuffleMode: ShuffleMode? { didSet { _player?._apply() } }
        weak var _player: MusicPlayer?
    }
    public class Queue: ObservableObject, ExpressibleByArrayLiteral, @unchecked Sendable {
        public struct Entry: Identifiable, Equatable, Hashable, Sendable {
            public enum Item: Equatable, Hashable, Sendable { case song(Song) }
            public let id: String
            public let title: String
            public let subtitle: String?
            public let artwork: Artwork?
            public let item: Item?
            public var isTransient: Bool { false }
            init(_ s: Song) { id = s.id.rawValue; title = s.title; subtitle = s.artistName; artwork = s.artwork; item = .song(s) }
        }
        public struct Entries: RandomAccessCollection, Sendable {
            let all: [Entry]
            public var startIndex: Int { 0 }
            public var endIndex: Int { all.count }
            public subscript(i: Int) -> Entry { all[i] }
        }
        public enum EntryInsertionPosition: Sendable { case afterCurrentEntry, tail }
        var songs: [Song]
        var start: Int
        weak var _player: MusicPlayer?
        public required init(arrayLiteral elements: Song...) { songs = elements; start = 0 }
        public init<S: Sequence>(for items: S, startingAt startItem: S.Element? = nil) where S.Element: PlayableMusicItem {
            let all = items.flatMap { Queue._songs($0) }
            songs = all
            start = startItem.flatMap { s in all.firstIndex { $0.id == s.id } } ?? 0
        }
        static func _songs(_ item: some PlayableMusicItem) -> [Song] {
            if let s = item as? Song { return [s] }
            if let a = item as? Album { return a._tracks }
            if let p = item as? Playlist { return p._tracks }
            if case .song(let s)? = item as? Track { return [s] }
            return []
        }
        public var entries: Entries { Entries(all: songs.map(Entry.init)) }
        public var currentEntry: Entry? {
            get {
                guard let i = _player?._controller.indexOfNowPlayingItem, i != NSNotFound, i < songs.count else { return songs.indices.contains(start) ? Entry(songs[start]) : nil }
                return Entry(songs[i])
            }
            set {}
        }
        public func insert<S: Sequence>(_ items: S, position: EntryInsertionPosition) async throws where S.Element: PlayableMusicItem {
            let new = items.flatMap { Queue._songs($0) }
            if position == .tail { songs += new } else {
                let i = (_player?._controller.indexOfNowPlayingItem).flatMap { $0 == NSNotFound ? nil : $0 + 1 } ?? songs.count
                songs.insert(contentsOf: new, at: min(i, songs.count))
            }
            _player?._load(keepPosition: true)
        }
    }

    let _controller: MPMusicPlayerController
    public let state = State()
    init(_ c: MPMusicPlayerController) {
        _controller = c
        state._player = self
        NotificationCenter.default.addObserver(forName: .MPMusicPlayerControllerPlaybackStateDidChange, object: c, queue: .main) { [weak self] _ in self?._sync() }
        c.beginGeneratingPlaybackNotifications()
    }
    var _queue = Queue()
    public var isPreparedToPlay: Bool { _controller.isPreparedToPlay }
    public var playbackTime: TimeInterval {
        get { _controller.currentPlaybackTime }
        set { _controller.currentPlaybackTime = newValue }
    }
    func _load(keepPosition: Bool = false) {
        _queue._player = self
        let items = _queue.songs.compactMap(_Library.mediaItem)
        let time = keepPosition ? _controller.currentPlaybackTime : 0
        let current = keepPosition ? _controller.nowPlayingItem : nil
        _controller.setQueue(with: MPMediaItemCollection(items: items))
        if let c = current { _controller.nowPlayingItem = c; _controller.currentPlaybackTime = time }
        else if _queue.start < items.count { _controller.nowPlayingItem = items[_queue.start] }
    }
    func _apply() {
        _controller.repeatMode = state.repeatMode.map { $0 == .one ? .one : $0 == .all ? .all : .none } ?? .default
        _controller.shuffleMode = state.shuffleMode.map { $0 == .songs ? .songs : .off } ?? .default
    }
    func _sync() {
        let s: PlaybackStatus
        switch _controller.playbackState {
        case .playing: s = .playing
        case .paused: s = .paused
        case .interrupted: s = .interrupted
        case .seekingForward: s = .seekingForward
        case .seekingBackward: s = .seekingBackward
        default: s = .stopped
        }
        if state.playbackStatus != s { state.playbackStatus = s }
        state.playbackRate = _controller.currentPlaybackRate
    }
    func _check() throws {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { throw MPError(.permissionDenied) }
        if _queue.songs.contains(where: { !$0._library }) {
            NSLog("isim MusicKit: catalog songs need an Apple Music subscription (none on isim)")
            throw MPError(.cloudServiceCapabilityMissing)
        }
    }
    public func prepareToPlay() async throws { try _check(); try await _controller.prepareToPlay() }
    public func play() async throws { try _check(); _controller.play(); _sync() }
    public func pause() { _controller.pause(); _sync() }
    public func stop() { _controller.stop(); _sync() }
    public func skipToNextEntry() async throws { _controller.skipToNextItem(); _sync() }
    public func skipToPreviousEntry() async throws { _controller.skipToPreviousItem(); _sync() }
    public func restartCurrentEntry() { _controller.skipToBeginning() }
    public func beginSeekingForward() { _controller.beginSeekingForward(); _sync() }
    public func beginSeekingBackward() { _controller.beginSeekingBackward(); _sync() }
    public func endSeeking() { _controller.endSeeking(); _sync() }
}

/// The app's own player (stops with the app).
public final class ApplicationMusicPlayer: MusicPlayer, @unchecked Sendable {
    public static let shared = ApplicationMusicPlayer(.applicationQueuePlayer)
    public var queue: MusicPlayer.Queue {
        get { _queue }
        set { _queue = newValue; _load() }
    }
}
/// The Music app's player (here: MediaPlayer's system music player).
public final class SystemMusicPlayer: MusicPlayer, @unchecked Sendable {
    public static let shared = SystemMusicPlayer(.systemMusicPlayer)
    public var queue: MusicPlayer.Queue {
        get { _queue }
        set { _queue = newValue; _load() }
    }
}
