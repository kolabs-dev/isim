// isim MusicKit: the other music items (Genre, MusicVideo, Station, RecordLabel), catalog charts, library search,
// recently played items and personal recommendations, ArtworkImage and the subscription offer.
// - Catalog items, charts, recently played and recommendations are passthrough to the Apple Music API (MusicKit.swift:
//   ISIM_MUSICKIT_*); the last two are about the user and need ISIM_MUSICKIT_USER_TOKEN.
// - Library search runs over isim's simulated library (adapted: Apple's ranking is approximated by matches at the start
//   of the title first).
// - The subscription offer shows isim's own sheet: there is no Apple Music subscription to offer (adapted).
import Foundation
import SwiftUI

// MARK: - supporting types

public enum ContentRating: String, Equatable, Hashable, Sendable, Codable { case clean, explicit }

public struct EditorialNotes: Equatable, Hashable, Sendable, Codable {
    public let name: String?
    public let short: String?
    public let standard: String?
    public let tagline: String?
}

public struct PreviewAsset: Equatable, Hashable, Sendable {
    public let artwork: Artwork?
    public let hlsURL: URL?
    public let url: URL?
}

protocol _Related { var _rel: _Relations { get set } }
extension _Related {
    func related(_ r: _Relations) -> Self { var c = self; c._rel = r; return c }
}
extension Song: _Related {}
extension Album: _Related {}
extension Artist: _Related {}

// the filters MusicCatalogResourceRequest matches by (isim's filter type is the item itself, which conforms)
public protocol GenreFilter { var id: MusicItemID { get } }
public protocol MusicVideoFilter { var id: MusicItemID { get }; var isrc: String? { get } }
public protocol StationFilter { var id: MusicItemID { get } }
public protocol RecordLabelFilter { var id: MusicItemID { get } }

// MARK: - Genre

public struct Genre: MusicItem, FilterableMusicItem, MusicLibraryRequestable, MusicPropertyContainer, GenreFilter, _Related {
    public typealias FilterType = Genre
    public typealias LibraryFilter = Genre
    public let id: MusicItemID
    public var name: String
    public var parent: Genre? { _parent.first }
    public var libraryAddedDate: Date?
    let _parent: [Genre]
    var _rel = _Relations()
    init(id: MusicItemID, name: String, parent: Genre?, libraryAddedDate: Date?) {
        self.id = id; self.name = name; _parent = parent.map { [$0] } ?? []; self.libraryAddedDate = libraryAddedDate
    }
    public static func == (a: Genre, b: Genre) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - MusicVideo

public struct MusicVideo: MusicItem, MusicCatalogSearchable, FilterableMusicItem, MusicLibraryRequestable, PlayableMusicItem, MusicPropertyContainer,
                          MusicVideoFilter, _Related {
    public typealias FilterType = MusicVideo
    public typealias LibraryFilter = MusicVideo
    public static var _searchType: String { "music-videos" }
    public let id: MusicItemID
    public var title: String
    public var artistName: String
    public var artistURL: URL?
    public var albumTitle: String?
    public var artwork: Artwork?
    public var contentRating: ContentRating?
    public var duration: TimeInterval?
    public var editorialNotes: EditorialNotes?
    public var genreNames: [String]
    public var has4K: Bool?
    public var hasHDR: Bool?
    public var isrc: String?
    public var releaseDate: Date?
    public var trackNumber: Int?
    public var url: URL?
    public var workName: String?
    public var previewAssets: [PreviewAsset]?
    public var playParameters: PlayParameters?
    /// library-only (isim's library has no music videos)
    public var playCount: Int? { nil }
    public var lastPlayedDate: Date? { nil }
    public var libraryAddedDate: Date? { nil }
    /// classical works only
    public var startTime: TimeInterval? { nil }
    public var endTime: TimeInterval? { nil }
    /// catalog videos play only as previews (no subscription on isim)
    public var isPreview: Bool { false }
    var _rel = _Relations()
    public var albums: MusicItemCollection<Album>? { _collection(_rel.albums) }
    public var artists: MusicItemCollection<Artist>? { _collection(_rel.artists) }
    public var genres: MusicItemCollection<Genre>? { _collection(_rel.genres) }
    public var songs: MusicItemCollection<Song>? { _collection(_rel.songs) }
    public var moreByArtist: MusicItemCollection<MusicVideo>? { _rel.viewMusicVideos["more-by-artist"].map { MusicItemCollection($0) } }
    public var moreInGenre: MusicItemCollection<MusicVideo>? { _rel.viewMusicVideos["more-in-genre"].map { MusicItemCollection($0) } }
    public static let albums = PartialMusicProperty<MusicVideo>("albums"), artists = PartialMusicProperty<MusicVideo>("artists")
    public static let genres = PartialMusicProperty<MusicVideo>("genres"), songs = PartialMusicProperty<MusicVideo>("songs")
    public static let moreByArtist = PartialMusicProperty<MusicVideo>("more-by-artist", view: true)
    public static let moreInGenre = PartialMusicProperty<MusicVideo>("more-in-genre", view: true)
    public func with(_ properties: [PartialMusicProperty<MusicVideo>]) async throws -> MusicVideo {
        try await _AppleMusicAPI.reload("music-videos", id, properties.map { ($0.name, $0.view) }, _AppleMusicAPI.musicVideo)
    }
    public static func == (a: MusicVideo, b: MusicVideo) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - Station

public struct Station: MusicItem, MusicCatalogSearchable, FilterableMusicItem, PlayableMusicItem, MusicPropertyContainer, StationFilter, _Related {
    public typealias FilterType = Station
    public static var _searchType: String { "stations" }
    public let id: MusicItemID
    public var name: String
    public var artwork: Artwork?
    public var contentRating: ContentRating?
    public var duration: TimeInterval?
    public var editorialNotes: EditorialNotes?
    public var episodeNumber: Int?
    public var isLive: Bool
    public var stationProviderName: String?
    public var url: URL?
    public var playParameters: PlayParameters?
    var _rel = _Relations()
    public func with(_ properties: [PartialMusicProperty<Station>]) async throws -> Station {
        try await _AppleMusicAPI.reload("stations", id, properties.map { ($0.name, $0.view) }, _AppleMusicAPI.station)
    }
    public static func == (a: Station, b: Station) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - RecordLabel

public struct RecordLabel: MusicItem, MusicCatalogSearchable, FilterableMusicItem, MusicPropertyContainer, RecordLabelFilter, _Related {
    public typealias FilterType = RecordLabel
    public static var _searchType: String { "record-labels" }
    public let id: MusicItemID
    public var name: String
    public var artwork: Artwork?
    public var shortDescription: String?
    public var standardDescription: String?
    public var url: URL?
    var _rel = _Relations()
    public var latestReleases: MusicItemCollection<Album>? { _rel.viewAlbums["latest-releases"].map { MusicItemCollection($0) } }
    public var topReleases: MusicItemCollection<Album>? { _rel.viewAlbums["top-releases"].map { MusicItemCollection($0) } }
    public static let latestReleases = PartialMusicProperty<RecordLabel>("latest-releases", view: true)
    public static let topReleases = PartialMusicProperty<RecordLabel>("top-releases", view: true)
    public func with(_ properties: [PartialMusicProperty<RecordLabel>]) async throws -> RecordLabel {
        try await _AppleMusicAPI.reload("record-labels", id, properties.map { ($0.name, $0.view) }, _AppleMusicAPI.recordLabel)
    }
    public static func == (a: RecordLabel, b: RecordLabel) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - Apple Music API resources

extension _AppleMusicAPI {
    static func url(_ a: [String: Any], _ k: String) -> URL? { (a[k] as? String).flatMap(URL.init(string:)) }
    static func notes(_ a: Any?) -> EditorialNotes? {
        guard let n = a as? [String: Any] else { return nil }
        return EditorialNotes(name: n["name"] as? String, short: n["short"] as? String, standard: n["standard"] as? String, tagline: n["tagline"] as? String)
    }
    static func rating(_ a: Any?) -> ContentRating? { (a as? String).flatMap(ContentRating.init(rawValue:)) }
    static func data(_ r: [String: Any], _ group: String, _ key: String) -> [[String: Any]]? {
        ((r[group] as? [String: Any])?[key] as? [String: Any])?["data"] as? [[String: Any]]
    }
    /// the relationships and views of a resource
    static func relations(_ r: [String: Any]) -> _Relations {
        var x = _Relations()
        x.albums = data(r, "relationships", "albums")?.map(album)
        x.artists = data(r, "relationships", "artists")?.map(artist)
        x.genres = data(r, "relationships", "genres")?.map(genre)
        x.musicVideos = data(r, "relationships", "music-videos")?.map(musicVideo)
        x.songs = data(r, "relationships", "songs")?.map(song)
        x.stations = (data(r, "relationships", "station") ?? data(r, "relationships", "stations"))?.map(station)
        x.recordLabels = data(r, "relationships", "record-labels")?.map(recordLabel)
        for (name, value) in (r["views"] as? [String: Any]) ?? [:] {
            let items = (value as? [String: Any])?["data"] as? [[String: Any]] ?? []
            if items.allSatisfy({ ($0["type"] as? String) == "music-videos" }) && !items.isEmpty { x.viewMusicVideos[name] = items.map(musicVideo) }
            else { x.viewAlbums[name] = items.filter { ($0["type"] as? String) == "albums" }.map(album) }
        }
        return x
    }
    static func genre(_ r: [String: Any]) -> Genre {
        let a = r["attributes"] as? [String: Any] ?? [:]
        let parent = (a["parentId"] as? String).map { Genre(id: MusicItemID($0), name: a["parentName"] as? String ?? "", parent: nil, libraryAddedDate: nil) }
        return Genre(id: MusicItemID(r["id"] as? String ?? ""), name: a["name"] as? String ?? "", parent: parent, libraryAddedDate: nil).related(relations(r))
    }
    static func musicVideo(_ r: [String: Any]) -> MusicVideo {
        let a = r["attributes"] as? [String: Any] ?? [:]
        let id = MusicItemID(r["id"] as? String ?? "")
        let previews = (a["previews"] as? [[String: Any]])?.map { PreviewAsset(artwork: artwork($0["artwork"]), hlsURL: url($0, "hlsUrl"), url: url($0, "url")) }
        return MusicVideo(id: id, title: a["name"] as? String ?? "", artistName: a["artistName"] as? String ?? "", artistURL: url(a, "artistUrl"),
                          albumTitle: a["albumName"] as? String, artwork: artwork(a["artwork"]), contentRating: rating(a["contentRating"]),
                          duration: (a["durationInMillis"] as? Double).map { $0 / 1000 }, editorialNotes: notes(a["editorialNotes"]),
                          genreNames: a["genreNames"] as? [String] ?? [], has4K: a["has4K"] as? Bool, hasHDR: a["hasHDR"] as? Bool, isrc: a["isrc"] as? String,
                          releaseDate: date(a["releaseDate"]), trackNumber: a["trackNumber"] as? Int, url: url(a, "url"), workName: a["workName"] as? String,
                          previewAssets: previews, playParameters: PlayParameters(id: id, kind: "musicVideo", library: false)).related(relations(r))
    }
    static func station(_ r: [String: Any]) -> Station {
        let a = r["attributes"] as? [String: Any] ?? [:]
        let id = MusicItemID(r["id"] as? String ?? "")
        return Station(id: id, name: a["name"] as? String ?? "", artwork: artwork(a["artwork"]), contentRating: rating(a["contentRating"]),
                       duration: (a["durationInMillis"] as? Double).map { $0 / 1000 }, editorialNotes: notes(a["editorialNotes"]),
                       episodeNumber: (a["episodeNumber"] as? Int) ?? (a["episodeNumber"] as? String).flatMap { Int($0) }, isLive: a["isLive"] as? Bool ?? false,
                       stationProviderName: a["stationProviderName"] as? String, url: url(a, "url"),
                       playParameters: PlayParameters(id: id, kind: "radioStation", library: false)).related(relations(r))
    }
    static func recordLabel(_ r: [String: Any]) -> RecordLabel {
        let a = r["attributes"] as? [String: Any] ?? [:]
        let d = a["description"] as? [String: Any]
        return RecordLabel(id: MusicItemID(r["id"] as? String ?? ""), name: a["name"] as? String ?? "", artwork: artwork(a["artwork"]),
                           shortDescription: d?["short"] as? String, standardDescription: d?["standard"] as? String, url: url(a, "url")).related(relations(r))
    }
    /// the catalog resource again, with relationships (`include`) and views
    static func reload<T>(_ type: String, _ id: MusicItemID, _ properties: [(String, Bool)], _ parse: ([String: Any]) -> T) async throws -> T {
        var q: [URLQueryItem] = []
        let rels = properties.filter { !$0.1 }.map(\.0), views = properties.filter(\.1).map(\.0)
        if !rels.isEmpty { q.append(URLQueryItem(name: "include", value: rels.joined(separator: ","))) }
        if !views.isEmpty { q.append(URLQueryItem(name: "views", value: views.joined(separator: ","))) }
        let json = try await get("/v1/catalog/\(storefront)/\(type)/\(id.rawValue)", q)
        guard let r = (json["data"] as? [[String: Any]])?.first else {
            throw MusicDataRequest.Error(status: 404, code: "40400", title: "Resource Not Found", detailText: "no \(type) \(id.rawValue)")
        }
        return parse(r)
    }
    static func pageQuery(_ limit: Int?, _ offset: Int?) -> [URLQueryItem] {
        (limit.map { [URLQueryItem(name: "limit", value: "\($0)")] } ?? []) + (offset.map { [URLQueryItem(name: "offset", value: "\($0)")] } ?? [])
    }
}

// MARK: - charts

public protocol MusicCatalogChartRequestable: MusicItem {}
extension Song: MusicCatalogChartRequestable {}
extension Album: MusicCatalogChartRequestable {}
extension Playlist: MusicCatalogChartRequestable {}
extension MusicVideo: MusicCatalogChartRequestable {}

public enum MusicCatalogChartKind: Equatable, Hashable, Sendable, CustomStringConvertible {
    case mostPlayed, dailyGlobalTop, cityTop
    /// the Apple Music API's chart name
    var _api: String { switch self { case .mostPlayed: return "most-played"; case .dailyGlobalTop: return "dailyGlobalTopCharts"; case .cityTop: return "cityCharts" } }
    public var description: String { switch self { case .mostPlayed: return "mostPlayed"; case .dailyGlobalTop: return "dailyGlobalTop"; case .cityTop: return "cityTop" } }
}

public struct MusicCatalogChart<MusicItemType: MusicCatalogChartRequestable>: Identifiable, Hashable, Sendable, CustomStringConvertible {
    public let id: String
    public let title: String
    public let kind: MusicCatalogChartKind
    public let items: MusicItemCollection<MusicItemType>
    public static func == (a: MusicCatalogChart, b: MusicCatalogChart) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
    public var description: String { "MusicCatalogChart(\(title), \(items.count) items)" }
}

public struct MusicCatalogChartsRequest {
    public var genre: Genre?
    public var kinds: [MusicCatalogChartKind]
    public var types: [any MusicCatalogChartRequestable.Type]
    public var limit: Int?
    public var offset: Int?
    public init(genre: Genre? = nil, kinds: [MusicCatalogChartKind] = [.mostPlayed], types: [any MusicCatalogChartRequestable.Type]) {
        self.genre = genre; self.kinds = kinds; self.types = types
    }
    public func response() async throws -> MusicCatalogChartsResponse {
        let names: [String] = types.compactMap {
            $0 == Song.self ? "songs" : $0 == Album.self ? "albums" : $0 == Playlist.self ? "playlists" : $0 == MusicVideo.self ? "music-videos" : nil
        }
        var q = [URLQueryItem(name: "types", value: names.joined(separator: ",")), URLQueryItem(name: "chart", value: kinds.map(\._api).joined(separator: ","))]
        if let genre { q.append(URLQueryItem(name: "genre", value: genre.id.rawValue)) }
        q += _AppleMusicAPI.pageQuery(limit, offset)
        let json = try await _AppleMusicAPI.get("/v1/catalog/\(_AppleMusicAPI.storefront)/charts", q)
        let results = json["results"] as? [String: Any] ?? [:]
        func charts<T>(_ key: String, _ parse: ([String: Any]) -> T) -> [MusicCatalogChart<T>] {
            ((results[key] as? [[String: Any]]) ?? []).map { c in
                let name = c["chart"] as? String ?? "most-played"
                let kind: MusicCatalogChartKind = name == "cityCharts" ? .cityTop : name == "dailyGlobalTopCharts" ? .dailyGlobalTop : .mostPlayed
                return MusicCatalogChart(id: c["orderId"] as? String ?? "\(name):\(key)", title: c["name"] as? String ?? "", kind: kind,
                                         items: MusicItemCollection((c["data"] as? [[String: Any]] ?? []).map(parse)))
            }
        }
        return MusicCatalogChartsResponse(songCharts: charts("songs", _AppleMusicAPI.song), albumCharts: charts("albums", _AppleMusicAPI.album),
                                          playlistCharts: charts("playlists", _AppleMusicAPI.playlist),
                                          musicVideoCharts: charts("music-videos", _AppleMusicAPI.musicVideo))
    }
}
public struct MusicCatalogChartsResponse: Sendable {
    public let songCharts: [MusicCatalogChart<Song>]
    public let albumCharts: [MusicCatalogChart<Album>]
    public let playlistCharts: [MusicCatalogChart<Playlist>]
    public let musicVideoCharts: [MusicCatalogChart<MusicVideo>]
}

// MARK: - library search

public protocol MusicLibrarySearchable: MusicItem {}
extension Song: MusicLibrarySearchable {}
extension Album: MusicLibrarySearchable {}
extension Artist: MusicLibrarySearchable {}
extension Playlist: MusicLibrarySearchable {}
extension MusicVideo: MusicLibrarySearchable {}

public struct MusicLibrarySearchRequest {
    public let term: String
    public var types: [any MusicLibrarySearchable.Type]
    public var limit: Int = 25
    public var includeTopResults = false
    public init(term: String, types: [any MusicLibrarySearchable.Type]) { self.term = term; self.types = types }
    public func response() async throws -> MusicLibrarySearchResponse {
        guard _Library.authorized else { throw MusicDataRequest.Error(status: 403, code: "40300", title: "Forbidden", detailText: "music library access was not authorized") }
        let words = term.split(separator: " ").map(String.init)
        /// all the words in the item's text; matches at the start of the title rank first
        func rank(_ title: String, _ text: String) -> Int? {
            guard !words.isEmpty, words.allSatisfy({ text.localizedCaseInsensitiveContains($0) }) else { return nil }
            return title.lowercased().hasPrefix(term.lowercased()) ? 0 : title.localizedCaseInsensitiveContains(term) ? 1 : 2
        }
        func search<T>(_ t: T.Type, _ items: [T], _ title: (T) -> String, _ text: (T) -> String) -> [(T, Int)] {
            guard types.contains(where: { $0 == t }) else { return [] }
            return items.compactMap { i in rank(title(i), text(i)).map { (i, $0) } }.enumerated()
                .sorted { $0.element.1 != $1.element.1 ? $0.element.1 < $1.element.1 : $0.offset < $1.offset }.map(\.element)
        }
        // library items render their artwork: UIKit work, on the main thread
        let wanted = types.map { ObjectIdentifier($0) }
        func wants(_ t: Any.Type) -> Bool { wanted.contains(ObjectIdentifier(t)) }
        let (s, al, ar, pl) = await MainActor.run { [w = (wants(Song.self), wants(Album.self), wants(Artist.self), wants(Playlist.self))] in
            (w.0 ? _Library.songs() : [], w.1 ? _Library.albums() : [], w.2 ? _Library.artists() : [], w.3 ? _Library.playlists() : [])
        }
        let songs = search(Song.self, s, \.title) { "\($0.title) \($0.artistName) \($0.albumTitle ?? "")" }
        let albums = search(Album.self, al, \.title) { "\($0.title) \($0.artistName)" }
        let artists = search(Artist.self, ar, \.name) { $0.name }
        let playlists = search(Playlist.self, pl, \.name) { "\($0.name) \($0.curatorName ?? "")" }
        var top: [(MusicLibrarySearchResponse.TopResult, Int)] = []
        if includeTopResults {
            top = songs.map { (.song($0.0), $0.1) } + albums.map { (.album($0.0), $0.1) } + artists.map { (.artist($0.0), $0.1) } + playlists.map { (.playlist($0.0), $0.1) }
            top = top.enumerated().sorted { $0.element.1 != $1.element.1 ? $0.element.1 < $1.element.1 : $0.offset < $1.offset }.map(\.element)
        }
        func cut<T>(_ a: [(T, Int)]) -> [T] { Array(a.map(\.0).prefix(max(0, limit))) }
        return MusicLibrarySearchResponse(songs: MusicItemCollection(cut(songs)), albums: MusicItemCollection(cut(albums)), artists: MusicItemCollection(cut(artists)),
                                          playlists: MusicItemCollection(cut(playlists)), musicVideos: [], topResults: MusicItemCollection(cut(top)))
    }
}
public struct MusicLibrarySearchResponse: Sendable {
    public enum TopResult: MusicItem {
        case album(Album), artist(Artist), musicVideo(MusicVideo), playlist(Playlist), song(Song)
        public var id: MusicItemID {
            switch self { case .album(let x): return x.id; case .artist(let x): return x.id; case .musicVideo(let x): return x.id; case .playlist(let x): return x.id; case .song(let x): return x.id }
        }
        public var title: String {
            switch self { case .album(let x): return x.title; case .artist(let x): return x.name; case .musicVideo(let x): return x.title; case .playlist(let x): return x.name; case .song(let x): return x.title }
        }
        public var artwork: Artwork? {
            switch self { case .album(let x): return x.artwork; case .artist(let x): return x.artwork; case .musicVideo(let x): return x.artwork; case .playlist(let x): return x.artwork; case .song(let x): return x.artwork }
        }
    }
    public let songs: MusicItemCollection<Song>
    public let albums: MusicItemCollection<Album>
    public let artists: MusicItemCollection<Artist>
    public let playlists: MusicItemCollection<Playlist>
    public let musicVideos: MusicItemCollection<MusicVideo>
    public let topResults: MusicItemCollection<TopResult>
}

// MARK: - recently played

public protocol MusicRecentlyPlayedRequestable: MusicItem {}
extension Song: MusicRecentlyPlayedRequestable {}
extension MusicVideo: MusicRecentlyPlayedRequestable {}
extension Station: MusicRecentlyPlayedRequestable {}

/// a recently played container: an album, a playlist or a station
public enum RecentlyPlayedMusicItem: MusicItem, PlayableMusicItem, MusicRecentlyPlayedRequestable {
    case album(Album), playlist(Playlist), station(Station)
    public var id: MusicItemID { switch self { case .album(let x): return x.id; case .playlist(let x): return x.id; case .station(let x): return x.id } }
    public var title: String { switch self { case .album(let x): return x.title; case .playlist(let x): return x.name; case .station(let x): return x.name } }
    public var subtitle: String? { switch self { case .album(let x): return x.artistName; case .playlist(let x): return x.curatorName; case .station(let x): return x.stationProviderName } }
    public var artwork: Artwork? { switch self { case .album(let x): return x.artwork; case .playlist(let x): return x.artwork; case .station(let x): return x.artwork } }
    public var playParameters: PlayParameters? {
        switch self { case .album(let x): return x.playParameters; case .playlist(let x): return x.playParameters; case .station(let x): return x.playParameters }
    }
}
public typealias MusicRecentlyPlayedContainerRequest = MusicRecentlyPlayedRequest<RecentlyPlayedMusicItem>
public typealias MusicRecentlyPlayedContainerResponse = MusicRecentlyPlayedResponse<RecentlyPlayedMusicItem>

public struct MusicRecentlyPlayedRequest<MusicItemType: MusicRecentlyPlayedRequestable> {
    public var limit: Int?
    public var offset: Int?
    public init() {}
    public func response() async throws -> MusicRecentlyPlayedResponse<MusicItemType> {
        let path: String, query: [URLQueryItem]
        switch MusicItemType.self {
        case is Song.Type: (path, query) = ("/v1/me/recent/played/tracks", [URLQueryItem(name: "types", value: "songs")])
        case is MusicVideo.Type: (path, query) = ("/v1/me/recent/played/tracks", [URLQueryItem(name: "types", value: "music-videos")])
        case is Station.Type: (path, query) = ("/v1/me/recent/radio-stations", [])
        default: (path, query) = ("/v1/me/recent/played", [])
        }
        let json = try await _AppleMusicAPI.get(path, query + _AppleMusicAPI.pageQuery(limit, offset), user: true)
        let data = json["data"] as? [[String: Any]] ?? []
        let items: [MusicItemType]
        if MusicItemType.self == RecentlyPlayedMusicItem.self {
            items = data.compactMap { r -> RecentlyPlayedMusicItem? in
                switch r["type"] as? String {
                case "albums", "library-albums": return .album(_AppleMusicAPI.album(r))
                case "playlists", "library-playlists": return .playlist(_AppleMusicAPI.playlist(r))
                case "stations": return .station(_AppleMusicAPI.station(r))
                default: return nil
                }
            } as! [MusicItemType]
        } else {
            items = _AppleMusicAPI.items(data, MusicItemType.self)
        }
        return MusicRecentlyPlayedResponse(items: MusicItemCollection(items))
    }
}
public struct MusicRecentlyPlayedResponse<MusicItemType: MusicItem>: Sendable {
    public let items: MusicItemCollection<MusicItemType>
}

// MARK: - personal recommendations

public protocol MusicPersonalRecommendationItem: MusicItem {}
extension Album: MusicPersonalRecommendationItem {}
extension Playlist: MusicPersonalRecommendationItem {}
extension Station: MusicPersonalRecommendationItem {}

public struct MusicPersonalRecommendation: MusicItem {
    public enum Item: MusicItem {
        case album(Album), playlist(Playlist), station(Station)
        public var id: MusicItemID { switch self { case .album(let x): return x.id; case .playlist(let x): return x.id; case .station(let x): return x.id } }
        public var title: String { switch self { case .album(let x): return x.title; case .playlist(let x): return x.name; case .station(let x): return x.name } }
        public var subtitle: String? { switch self { case .album(let x): return x.artistName; case .playlist(let x): return x.curatorName; case .station(let x): return x.stationProviderName } }
        public var artwork: Artwork? { switch self { case .album(let x): return x.artwork; case .playlist(let x): return x.artwork; case .station(let x): return x.artwork } }
    }
    public let id: MusicItemID
    public let title: String?
    public let reason: String?
    public let nextRefreshDate: Date?
    let _items: [Item]
    let _types: [String]
    public var items: MusicItemCollection<Item> { MusicItemCollection(_items) }
    public var albums: MusicItemCollection<Album> { MusicItemCollection(_items.compactMap { if case .album(let a) = $0 { return a }; return nil }) }
    public var playlists: MusicItemCollection<Playlist> { MusicItemCollection(_items.compactMap { if case .playlist(let p) = $0 { return p }; return nil }) }
    public var stations: MusicItemCollection<Station> { MusicItemCollection(_items.compactMap { if case .station(let s) = $0 { return s }; return nil }) }
    /// the kinds of items it recommends
    public var types: [any MusicPersonalRecommendationItem.Type] {
        _types.compactMap { $0 == "albums" ? Album.self : $0 == "playlists" ? Playlist.self : $0 == "stations" ? Station.self : nil }
    }
    public static func == (a: MusicPersonalRecommendation, b: MusicPersonalRecommendation) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

public struct MusicPersonalRecommendationsRequest {
    public var limit: Int?
    public var offset: Int?
    let _ids: [MusicItemID]
    public init() { _ids = [] }
    /// the given recommendations again, refreshed
    public init<S: Sequence>(refreshing recommendations: S) where S.Element == MusicPersonalRecommendation { _ids = recommendations.map(\.id) }
    public func response() async throws -> MusicPersonalRecommendationsResponse {
        var q = _AppleMusicAPI.pageQuery(limit, offset)
        if !_ids.isEmpty { q.append(URLQueryItem(name: "ids", value: _ids.map(\.rawValue).joined(separator: ","))) }
        let json = try await _AppleMusicAPI.get("/v1/me/recommendations", q, user: true)
        let recs = (json["data"] as? [[String: Any]] ?? []).map { r -> MusicPersonalRecommendation in
            let a = r["attributes"] as? [String: Any] ?? [:]
            func display(_ k: String) -> String? { (a[k] as? [String: Any])?["stringForDisplay"] as? String ?? a[k] as? String }
            let items = (_AppleMusicAPI.data(r, "relationships", "contents") ?? []).compactMap { c -> MusicPersonalRecommendation.Item? in
                switch c["type"] as? String {
                case "albums": return .album(_AppleMusicAPI.album(c))
                case "playlists": return .playlist(_AppleMusicAPI.playlist(c))
                case "stations": return .station(_AppleMusicAPI.station(c))
                default: return nil
                }
            }
            let next = (a["nextUpdateDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
            return MusicPersonalRecommendation(id: MusicItemID(r["id"] as? String ?? ""), title: display("title"), reason: display("reason"),
                                               nextRefreshDate: next, _items: items, _types: a["resourceTypes"] as? [String] ?? [])
        }
        return MusicPersonalRecommendationsResponse(recommendations: MusicItemCollection(recs))
    }
}
public struct MusicPersonalRecommendationsResponse: Sendable {
    public let recommendations: MusicItemCollection<MusicPersonalRecommendation>
}

// MARK: - SwiftUI

/// an item's artwork at a size: library artwork from its file, catalog artwork from the Apple Music URL template
public struct ArtworkImage: View {
    let artwork: Artwork
    let width: CGFloat?, height: CGFloat?
    public init(_ artwork: Artwork, width: CGFloat) { self.init(artwork, width: width, height: nil) }
    public init(_ artwork: Artwork, height: CGFloat) { self.init(artwork, width: nil, height: height) }
    public init(_ artwork: Artwork, width: CGFloat, height: CGFloat) { self.init(artwork, width: Optional(width), height: Optional(height)) }
    init(_ artwork: Artwork, width: CGFloat?, height: CGFloat?) { self.artwork = artwork; self.width = width; self.height = height }
    /// the size: the given one, the other side from the artwork's aspect ratio
    var _size: CGSize {
        let aspect = artwork.maximumWidth > 0 && artwork.maximumHeight > 0 ? CGFloat(artwork.maximumWidth) / CGFloat(artwork.maximumHeight) : 1
        let w = width ?? (height ?? 0) * aspect, h = height ?? (width ?? 0) / aspect
        return CGSize(width: w, height: h)
    }
    public var body: some View {
        let s = _size
        return AsyncImage(url: artwork.url(width: Int(s.width.rounded()), height: Int(s.height.rounded()))) { image in
            image.resizable()
        } placeholder: {
            Color.gray.opacity(0.3)
        }
        .frame(width: s.width, height: s.height)
        .accessibilityIdentifier("ArtworkImage")
    }
}

/// the Apple Music subscription offer (isim shows that there is no subscription to offer)
public struct MusicSubscriptionOffer {
    public struct Action: RawRepresentable, Equatable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let subscribe = Action("subscribe")
    }
    public struct MessageIdentifier: RawRepresentable, Equatable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let join = MessageIdentifier("join")
        public static let addMusic = MessageIdentifier("addMusic")
        public static let playMusic = MessageIdentifier("playMusic")
    }
    public struct Options: Equatable, Hashable, Sendable {
        public var action: Action
        public var messageIdentifier: MessageIdentifier
        public var itemID: MusicItemID?
        public var affiliateToken: String?
        public var campaignToken: String?
        public init(action: Action = .subscribe, messageIdentifier: MessageIdentifier = .join, itemID: MusicItemID? = nil,
                    affiliateToken: String? = nil, campaignToken: String? = nil) {
            self.action = action; self.messageIdentifier = messageIdentifier; self.itemID = itemID
            self.affiliateToken = affiliateToken; self.campaignToken = campaignToken
        }
        public static let `default` = Options()
    }
}

struct _MusicSubscriptionOfferSheet: View {
    let options: MusicSubscriptionOffer.Options
    @Binding var isPresented: Bool
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note").font(.system(size: 44)).foregroundColor(.pink)
            Text("Apple Music").font(.title2).bold()
            Text(options.messageIdentifier == .playMusic ? "Playing this needs an Apple Music subscription, which isim cannot offer."
                 : options.messageIdentifier == .addMusic ? "Adding music needs an Apple Music subscription, which isim cannot offer."
                 : "Apple Music subscriptions are not available on isim.")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            Button("Not Now") { isPresented = false }.accessibilityIdentifier("MusicSubscriptionOffer.close")
        }
        .padding(32)
        .accessibilityIdentifier("MusicSubscriptionOffer")
    }
}

extension View {
    /// presents the subscription offer; onLoadCompletion gets nil once the sheet has loaded
    public func musicSubscriptionOffer(isPresented: Binding<Bool>, options: MusicSubscriptionOffer.Options = .default,
                                       onLoadCompletion: @escaping ((any Error)?) -> Void = { _ in }) -> some View {
        sheet(isPresented: isPresented) {
            _MusicSubscriptionOfferSheet(options: options, isPresented: isPresented)
                .onAppear {
                    NSLog("isim MusicKit: subscription offer shown (%@, %@); no Apple Music subscription on isim", options.action.rawValue, options.messageIdentifier.rawValue)
                    onLoadCompletion(nil)
                }
        }
    }
}

// MARK: - with(_:) shorthand: `.albums` in a [PartialMusicProperty<Song>] names Song.albums

extension PartialMusicProperty where Root == Song {
    public static var albums: PartialMusicProperty<Song> { Song.albums }
    public static var artists: PartialMusicProperty<Song> { Song.artists }
    public static var genres: PartialMusicProperty<Song> { Song.genres }
    public static var musicVideos: PartialMusicProperty<Song> { Song.musicVideos }
    public static var station: PartialMusicProperty<Song> { Song.station }
}
extension PartialMusicProperty where Root == Album {
    public static var tracks: PartialMusicProperty<Album> { Album.tracks }
    public static var artists: PartialMusicProperty<Album> { Album.artists }
    public static var genres: PartialMusicProperty<Album> { Album.genres }
    public static var recordLabels: PartialMusicProperty<Album> { Album.recordLabels }
}
extension PartialMusicProperty where Root == Artist {
    public static var albums: PartialMusicProperty<Artist> { Artist.albums }
    public static var genres: PartialMusicProperty<Artist> { Artist.genres }
    public static var musicVideos: PartialMusicProperty<Artist> { Artist.musicVideos }
}
extension PartialMusicProperty where Root == Playlist {
    public static var tracks: PartialMusicProperty<Playlist> { Playlist.tracks }
    public static var entries: PartialMusicProperty<Playlist> { Playlist.entries }
}
extension PartialMusicProperty where Root == MusicVideo {
    public static var albums: PartialMusicProperty<MusicVideo> { MusicVideo.albums }
    public static var artists: PartialMusicProperty<MusicVideo> { MusicVideo.artists }
    public static var genres: PartialMusicProperty<MusicVideo> { MusicVideo.genres }
    public static var songs: PartialMusicProperty<MusicVideo> { MusicVideo.songs }
    public static var moreByArtist: PartialMusicProperty<MusicVideo> { MusicVideo.moreByArtist }
    public static var moreInGenre: PartialMusicProperty<MusicVideo> { MusicVideo.moreInGenre }
}
extension PartialMusicProperty where Root == RecordLabel {
    public static var latestReleases: PartialMusicProperty<RecordLabel> { RecordLabel.latestReleases }
    public static var topReleases: PartialMusicProperty<RecordLabel> { RecordLabel.topReleases }
}
