// isim MediaPlayer: the device's music library — MPMediaLibrary (authorization, change notifications, playlists),
// MPMediaQuery (songs, albums, artists, genres, composers, playlists; predicates, grouping, sections), MPMediaItem,
// MPMediaItemCollection, MPMediaPlaylist, MPMusicPlayerController (system, application and queue players) and
// MPMediaPickerController. Self-authored. Adapted (the Simulator has no music library): the library is the
// device data's Media/Music folder. A new device gets six generated songs (two albums by two artists, stand-ins for
// a user's music, isim's own synthesized tunes); audio files copied into the folder (m4a, mp3, wav, aiff, caf,
// flac) join it, titled by their file name, and library.json holds the metadata. Players play in the app (through
// AVAudioPlayer) and show in Control Center; Apple Music catalog items (store IDs) cannot play.
import UIKit
import AVFoundation
import isim_host

public let MPMediaItemPropertyAlbumPersistentID = "albumPID"
public let MPMediaItemPropertyArtistPersistentID = "artistPID"
public let MPMediaItemPropertyAlbumArtistPersistentID = "albumArtistPID"
public let MPMediaItemPropertyGenrePersistentID = "genrePID"
public let MPMediaItemPropertyComposerPersistentID = "composerPID"
public let MPMediaItemPropertyAssetURL = "assetURL"
public let MPMediaItemPropertyIsCompilation = "isCompilation"
public let MPMediaItemPropertyReleaseDate = "releaseDate"
public let MPMediaItemPropertyPlayCount = "playCount"
public let MPMediaItemPropertyRating = "rating"
public let MPMediaItemPropertyLastPlayedDate = "lastPlayedDate"
public let MPMediaItemPropertyDateAdded = "dateAdded"
public let MPMediaItemPropertyIsCloudItem = "isCloudItem"
public let MPMediaItemPropertyHasProtectedAsset = "hasProtectedAsset"
public let MPMediaItemPropertyIsExplicit = "isExplicit"
public let MPMediaItemPropertyDiscNumber = "discNumber"
public let MPMediaItemPropertyAlbumTrackCount = "albumTrackCount"
public let MPMediaItemPropertyPlaybackStoreID = "playbackStoreID"
public let MPMediaPlaylistPropertyPersistentID = "playlistPersistentID"
public let MPMediaPlaylistPropertyName = "name"
public let MPMediaPlaylistPropertyPlaylistAttributes = "playlistAttributes"
public let MPMediaPlaylistPropertySeedItems = "seedItems"
public let MPMediaPlaylistPropertyDescriptionText = "descriptionText"
public let MPMediaPlaylistPropertyAuthorDisplayName = "authorDisplayName"

public typealias MPMediaEntityPersistentID = UInt64

public struct MPMediaType: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let music = MPMediaType(rawValue: 1)
    public static let podcast = MPMediaType(rawValue: 2)
    public static let audioBook = MPMediaType(rawValue: 4)
    public static let audioITunesU = MPMediaType(rawValue: 8)
    public static let anyAudio = MPMediaType(rawValue: 0xFF)
    public static let movie = MPMediaType(rawValue: 1 << 8)
    public static let tvShow = MPMediaType(rawValue: 1 << 9)
    public static let videoPodcast = MPMediaType(rawValue: 1 << 10)
    public static let musicVideo = MPMediaType(rawValue: 1 << 11)
    public static let videoITunesU = MPMediaType(rawValue: 1 << 12)
    public static let homeVideo = MPMediaType(rawValue: 1 << 13)
    public static let anyVideo = MPMediaType(rawValue: 0xFF00)
    public static let any = MPMediaType(rawValue: ~0)
}

// MARK: - entities

open class MPMediaEntity: NSObject, @unchecked Sendable {
    open class func canFilter(byProperty property: String) -> Bool {
        [MPMediaItemPropertyPersistentID, MPMediaItemPropertyMediaType, MPMediaItemPropertyTitle, MPMediaItemPropertyAlbumTitle,
         MPMediaItemPropertyArtist, MPMediaItemPropertyAlbumArtist, MPMediaItemPropertyGenre, MPMediaItemPropertyComposer,
         MPMediaItemPropertyAlbumPersistentID, MPMediaItemPropertyArtistPersistentID, MPMediaItemPropertyAlbumArtistPersistentID,
         MPMediaItemPropertyGenrePersistentID, MPMediaItemPropertyComposerPersistentID, MPMediaItemPropertyIsCompilation,
         MPMediaItemPropertyIsCloudItem, MPMediaItemPropertyHasProtectedAsset, MPMediaPlaylistPropertyName,
         MPMediaPlaylistPropertyPersistentID].contains(property)
    }
    open func value(forProperty property: String) -> Any? { nil }
    open func enumerateValues(forProperties properties: Set<String>, using block: (String, Any, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        for p in properties { if let v = value(forProperty: p) { block(p, v, &stop); if stop.boolValue { return } } }
    }
    open subscript(key: Any) -> Any? { (key as? String).flatMap { value(forProperty: $0) } }
    open var persistentID: MPMediaEntityPersistentID { 0 }
}

/// Stable 64-bit IDs from names (FNV-1a), like the library's persistent IDs.
func _mpid(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100_0000_01b3 }
    return h & 0x7FFF_FFFF_FFFF_FFFF
}

open class MPMediaItem: MPMediaEntity, @unchecked Sendable {
    let record: _MusicLibrary.Song
    init(_ r: _MusicLibrary.Song) { record = r }
    open override var persistentID: MPMediaEntityPersistentID { _mpid("song:" + record.file) }
    open var mediaType: MPMediaType { .music }
    open var title: String? { record.title }
    open var albumTitle: String? { record.album }
    open var albumPersistentID: MPMediaEntityPersistentID { _mpid("album:" + (record.album ?? "")) }
    open var artist: String? { record.artist }
    open var artistPersistentID: MPMediaEntityPersistentID { _mpid("artist:" + (record.artist ?? "")) }
    open var albumArtist: String? { record.albumArtist ?? record.artist }
    open var albumArtistPersistentID: MPMediaEntityPersistentID { _mpid("artist:" + (albumArtist ?? "")) }
    open var genre: String? { record.genre }
    open var genrePersistentID: MPMediaEntityPersistentID { _mpid("genre:" + (record.genre ?? "")) }
    open var composer: String? { record.composer }
    open var composerPersistentID: MPMediaEntityPersistentID { _mpid("composer:" + (record.composer ?? "")) }
    open var playbackDuration: TimeInterval { record.duration }
    open var albumTrackNumber: Int { record.track ?? 0 }
    open var albumTrackCount: Int { _MusicLibrary.shared.songs.filter { $0.album == record.album }.count }
    open var discNumber: Int { 1 }
    open var discCount: Int { 1 }
    open var artwork: MPMediaItemArtwork? { _MusicLibrary.artwork(for: record) }
    open var isExplicitItem: Bool { false }
    open var lyrics: String? { nil }
    open var isCompilation: Bool { false }
    open var releaseDate: Date? { record.year.flatMap { DateComponents(calendar: Calendar(identifier: .gregorian), year: $0, month: 1, day: 1).date } }
    open var beatsPerMinute: Int { 0 }
    open var comments: String? { nil }
    /// a file URL in the device's music folder (iOS: an ipod-library:// URL that AVFoundation opens)
    open var assetURL: URL? { URL(fileURLWithPath: _MusicLibrary.dir).appendingPathComponent(record.file) }
    open var isCloudItem: Bool { false }
    open var hasProtectedAsset: Bool { false }
    open var podcastTitle: String? { nil }
    open var playCount: Int { _MusicLibrary.shared.stats(record.file).0 }
    open var skipCount: Int { 0 }
    open var rating: Int { 0 }
    open var lastPlayedDate: Date? { _MusicLibrary.shared.stats(record.file).1 }
    open var userGrouping: String? { nil }
    open var bookmarkTime: TimeInterval { 0 }
    open var dateAdded: Date { record.added }
    open var playbackStoreID: String { "" }
    open var isPreorder: Bool { false }
    open override func value(forProperty property: String) -> Any? {
        switch property {
        case MPMediaItemPropertyPersistentID: return NSNumber(value: persistentID)
        case MPMediaItemPropertyMediaType: return NSNumber(value: mediaType.rawValue)
        case MPMediaItemPropertyTitle: return title
        case MPMediaItemPropertyAlbumTitle: return albumTitle
        case MPMediaItemPropertyAlbumPersistentID: return NSNumber(value: albumPersistentID)
        case MPMediaItemPropertyArtist: return artist
        case MPMediaItemPropertyArtistPersistentID: return NSNumber(value: artistPersistentID)
        case MPMediaItemPropertyAlbumArtist: return albumArtist
        case MPMediaItemPropertyAlbumArtistPersistentID: return NSNumber(value: albumArtistPersistentID)
        case MPMediaItemPropertyGenre: return genre
        case MPMediaItemPropertyGenrePersistentID: return NSNumber(value: genrePersistentID)
        case MPMediaItemPropertyComposer: return composer
        case MPMediaItemPropertyComposerPersistentID: return NSNumber(value: composerPersistentID)
        case MPMediaItemPropertyPlaybackDuration: return NSNumber(value: playbackDuration)
        case MPMediaItemPropertyAlbumTrackNumber: return NSNumber(value: albumTrackNumber)
        case MPMediaItemPropertyAlbumTrackCount: return NSNumber(value: albumTrackCount)
        case MPMediaItemPropertyDiscNumber: return NSNumber(value: discNumber)
        case MPMediaItemPropertyArtwork: return artwork
        case MPMediaItemPropertyAssetURL: return assetURL
        case MPMediaItemPropertyIsCompilation: return NSNumber(value: isCompilation)
        case MPMediaItemPropertyReleaseDate: return releaseDate
        case MPMediaItemPropertyPlayCount: return NSNumber(value: playCount)
        case MPMediaItemPropertyLastPlayedDate: return lastPlayedDate
        case MPMediaItemPropertyDateAdded: return dateAdded
        case MPMediaItemPropertyIsCloudItem: return NSNumber(value: false)
        case MPMediaItemPropertyHasProtectedAsset: return NSNumber(value: false)
        case MPMediaItemPropertyIsExplicit: return NSNumber(value: false)
        case MPMediaItemPropertyRating: return NSNumber(value: 0)
        case MPMediaItemPropertyPlaybackStoreID: return ""
        default: return nil
        }
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? MPMediaItem)?.persistentID == persistentID }
    open override var hash: Int { Int(truncatingIfNeeded: persistentID) }
}

open class MPMediaItemCollection: MPMediaEntity, @unchecked Sendable {
    public let items: [MPMediaItem]
    public init(items: [MPMediaItem]) { self.items = items }
    open var representativeItem: MPMediaItem? { items.first }
    open var count: Int { items.count }
    open var mediaTypes: MPMediaType { items.isEmpty ? [] : .music }
    open override var persistentID: MPMediaEntityPersistentID { _mpid("collection:" + items.map { String($0.persistentID) }.joined(separator: ",")) }
    open class func persistentIDProperty(forGroupingType groupingType: MPMediaGrouping) -> String {
        switch groupingType {
        case .album: return MPMediaItemPropertyAlbumPersistentID
        case .artist: return MPMediaItemPropertyArtistPersistentID
        case .albumArtist: return MPMediaItemPropertyAlbumArtistPersistentID
        case .composer: return MPMediaItemPropertyComposerPersistentID
        case .genre: return MPMediaItemPropertyGenrePersistentID
        case .playlist: return MPMediaPlaylistPropertyPersistentID
        default: return MPMediaItemPropertyPersistentID
        }
    }
    open class func titleProperty(forGroupingType groupingType: MPMediaGrouping) -> String {
        switch groupingType {
        case .album: return MPMediaItemPropertyAlbumTitle
        case .artist: return MPMediaItemPropertyArtist
        case .albumArtist: return MPMediaItemPropertyAlbumArtist
        case .composer: return MPMediaItemPropertyComposer
        case .genre: return MPMediaItemPropertyGenre
        case .playlist: return MPMediaPlaylistPropertyName
        default: return MPMediaItemPropertyTitle
        }
    }
}

public struct MPMediaPlaylistAttribute: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let onTheGo = MPMediaPlaylistAttribute(rawValue: 1)
    public static let smart = MPMediaPlaylistAttribute(rawValue: 2)
    public static let genius = MPMediaPlaylistAttribute(rawValue: 4)
}
open class MPMediaPlaylist: MPMediaItemCollection, @unchecked Sendable {
    let record: _MusicLibrary.Playlist
    init(_ r: _MusicLibrary.Playlist) {
        record = r
        super.init(items: r.songs.compactMap { f in _MusicLibrary.shared.songs.first { $0.file == f }.map(MPMediaItem.init) })
    }
    open override var persistentID: MPMediaEntityPersistentID { _mpid("playlist:" + record.id) }
    open var name: String? { record.name }
    open var playlistAttributes: MPMediaPlaylistAttribute { [] }
    open var seedItems: [MPMediaItem]? { nil }
    open var descriptionText: String? { record.text }
    open var authorDisplayName: String? { record.author }
    open var cloudGlobalID: String? { nil }
    open override func value(forProperty property: String) -> Any? {
        switch property {
        case MPMediaPlaylistPropertyPersistentID: return NSNumber(value: persistentID)
        case MPMediaPlaylistPropertyName: return name
        case MPMediaPlaylistPropertyPlaylistAttributes: return NSNumber(value: 0)
        case MPMediaPlaylistPropertyDescriptionText: return descriptionText
        case MPMediaPlaylistPropertyAuthorDisplayName: return authorDisplayName
        default: return nil
        }
    }
    /// adds library items to the playlist (playlists the app created)
    open func add(_ mediaItems: [MPMediaItem], completionHandler: ((Error?) -> Void)? = nil) {
        _MusicLibrary.shared.addToPlaylist(record.id, mediaItems.map { $0.record.file })
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    open func add(_ mediaItems: [MPMediaItem]) async throws { add(mediaItems, completionHandler: nil) }
    /// Apple Music catalog items cannot be added on isim
    open func addItem(withProductID productID: String, completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(MPError(.notFound)) }
    }
}
public struct MPError: Error, Sendable {
    public enum Code: Int, Sendable { case unknown = 0, permissionDenied, cloudServiceCapabilityMissing, networkConnectionFailed, notFound, notSupported, cancelled, requestTimedOut }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static let errorDomain = "MPErrorDomain"
}
open class MPMediaPlaylistCreationMetadata: NSObject {
    public let name: String
    open var authorDisplayName: String?
    open var descriptionText = ""
    public init(name: String) { self.name = name }
}

// MARK: - the library

public enum MPMediaLibraryAuthorizationStatus: Int, Sendable { case notDetermined = 0, denied, restricted, authorized }
public extension Notification.Name {
    static let MPMediaLibraryDidChange = Notification.Name("MPMediaLibraryDidChangeNotification")
    static let MPMusicPlayerControllerPlaybackStateDidChange = Notification.Name("MPMusicPlayerControllerPlaybackStateDidChangeNotification")
    static let MPMusicPlayerControllerNowPlayingItemDidChange = Notification.Name("MPMusicPlayerControllerNowPlayingItemDidChangeNotification")
    static let MPMusicPlayerControllerVolumeDidChange = Notification.Name("MPMusicPlayerControllerVolumeDidChangeNotification")
    static let MPMusicPlayerControllerQueueDidChange = Notification.Name("MPMusicPlayerControllerQueueDidChangeNotification")
}

open class MPMediaLibrary: NSObject, @unchecked Sendable {
    static let _default = MPMediaLibrary()
    open class func `default`() -> MPMediaLibrary { _default }
    open var lastModifiedDate: Date { _MusicLibrary.shared.modified }
    var notifying = 0
    open func beginGeneratingLibraryChangeNotifications() { notifying += 1 }
    open func endGeneratingLibraryChangeNotifications() { notifying = max(0, notifying - 1) }
    func changed() { if notifying > 0 { NotificationCenter.default.post(name: .MPMediaLibraryDidChange, object: self) } }

    /// the media library privacy alert (NSAppleMusicUsageDescription; ISIM_MEDIALIBRARY_PERMISSION=allow|deny answers it)
    open class func authorizationStatus() -> MPMediaLibraryAuthorizationStatus {
        _Privacy.stored("medialibrary").flatMap { MPMediaLibraryAuthorizationStatus(rawValue: $0) } ?? .notDetermined
    }
    open class func requestAuthorization(_ handler: @escaping @Sendable (MPMediaLibraryAuthorizationStatus) -> Void) {
        let s = authorizationStatus()
        if s != .notDetermined { _Privacy.reply { handler(s) }; return }
        guard let purpose = _Privacy.usage("NSAppleMusicUsageDescription", "MediaPlayer") else { _Privacy.reply { handler(.denied) }; return }
        _Privacy.onMain {
            func answer(_ ok: Bool) {
                let st: MPMediaLibraryAuthorizationStatus = ok ? .authorized : .denied
                _Privacy.store("medialibrary", st.rawValue)
                NSLog("isim MediaPlayer: media library access %@ for %@", ok ? "allowed" : "denied", _Privacy.appName)
                _Privacy.reply { handler(st) }
            }
            if let sc = _Privacy.scripted("MEDIALIBRARY") { answer(!(sc == "deny" || sc == "denied" || sc == "no" || sc == "0")); return }
            _Privacy.alert("“\(_Privacy.appName)” Would Like to Access Apple Music, Your Music and Video Activity, and Your Media Library", purpose,
                           [("Don’t Allow", .default), (_Privacy.osMajor >= 17 ? "Allow" : "OK", .default)]) { answer($0 == 1) }
        }
    }
    open class func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { k in requestAuthorization { k.resume(returning: $0) } }
    }
    /// adds a library item by its persistent ID (catalog product IDs cannot be added)
    open func addItem(withProductID productID: String, completionHandler: (([MPMediaEntity], Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?([], MPError(.notFound)) }
    }
    /// finds or creates an app playlist with this UUID
    open func getPlaylist(with uuid: UUID, creationMetadata: MPMediaPlaylistCreationMetadata?, completionHandler: @escaping (MPMediaPlaylist?, Error?) -> Void) {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { DispatchQueue.main.async { completionHandler(nil, MPError(.permissionDenied)) }; return }
        let lib = _MusicLibrary.shared
        if lib.playlists.first(where: { $0.id == uuid.uuidString }) == nil {
            guard let m = creationMetadata else { DispatchQueue.main.async { completionHandler(nil, nil) }; return }
            lib.createPlaylist(uuid.uuidString, m.name, m.descriptionText, m.authorDisplayName ?? _Privacy.appName)
            changed()
        }
        let p = lib.playlists.first { $0.id == uuid.uuidString }.map(MPMediaPlaylist.init)
        DispatchQueue.main.async { completionHandler(p, nil) }
    }
    open func getPlaylist(with uuid: UUID, creationMetadata: MPMediaPlaylistCreationMetadata?) async throws -> MPMediaPlaylist {
        try await withCheckedThrowingContinuation { k in
            getPlaylist(with: uuid, creationMetadata: creationMetadata) { p, e in if let p { k.resume(returning: p) } else { k.resume(throwing: e ?? MPError(.notFound)) } }
        }
    }
}

/// The library's storage: device data Media/Music (library.json and the audio files).
final class _MusicLibrary: @unchecked Sendable {
    struct Song: Codable { var file: String; var title: String; var artist: String?; var album: String?; var albumArtist: String?
                           var genre: String?; var composer: String?; var track: Int?; var year: Int?; var duration: Double; var added: Date
                           var hue: Double? }
    struct Playlist: Codable { var id: String; var name: String; var text: String?; var author: String?; var songs: [String] }
    struct Stats: Codable { var plays: [String: Int] = [:]; var last: [String: Date] = [:] }
    struct Store: Codable { var songs: [Song]; var playlists: [Playlist]; var stats: Stats? }
    static let shared = _MusicLibrary()
    static var dir: String { _Privacy.deviceDir("Media/Music") }
    var songs: [Song] = []
    var playlists: [Playlist] = []
    var stats = Stats()
    var modified = Date()
    var loaded = false
    let lock = NSRecursiveLock()

    func load() {
        lock.lock(); defer { lock.unlock() }
        let path = (Self.dir as NSString).appendingPathComponent("library.json")
        var store = _Privacy.readJSON(Store.self, path)
        if store == nil {
            store = Store(songs: Self.seed(), playlists: [], stats: nil)
            store!.playlists = [Playlist(id: "isim-favorites", name: "isim Favorites", text: "Songs of the simulated library", author: "isim",
                                         songs: [store!.songs[0].file, store!.songs[3].file, store!.songs[5].file].filter { _ in store!.songs.count >= 6 })]
            _Privacy.writeJSON(store!, path)
        }
        songs = store!.songs; playlists = store!.playlists; stats = store!.stats ?? Stats()
        // audio files copied into the folder join the library
        let known = Set(songs.map(\.file))
        let exts: Set<String> = ["m4a", "mp3", "wav", "aiff", "aif", "caf", "flac", "aac", "ogg"]
        var added = false
        for f in (try? FileManager.default.contentsOfDirectory(atPath: Self.dir))?.sorted() ?? [] where !known.contains(f) && exts.contains((f as NSString).pathExtension.lowercased()) {
            var info = isim_media_info()
            let full = (Self.dir as NSString).appendingPathComponent(f)
            let duration = isim_media_probe(full, &info) != 0 ? info.duration : 0
            songs.append(Song(file: f, title: (f as NSString).deletingPathExtension, artist: nil, album: nil, albumArtist: nil, genre: nil,
                              composer: nil, track: nil, year: nil, duration: duration, added: Date(), hue: nil))
            added = true
        }
        if added { save() }
        if let a = try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date { modified = a }
        loaded = true
    }
    func save() {
        _Privacy.writeJSON(Store(songs: songs, playlists: playlists, stats: stats), (Self.dir as NSString).appendingPathComponent("library.json"))
        modified = Date()
    }
    func ensure() { if !loaded { load() } }
    func stats(_ file: String) -> (Int, Date?) { lock.lock(); defer { lock.unlock() }; return (stats.plays[file] ?? 0, stats.last[file]) }
    func played(_ file: String) {
        lock.lock(); defer { lock.unlock() }
        stats.plays[file, default: 0] += 1; stats.last[file] = Date(); save()
    }
    func createPlaylist(_ id: String, _ name: String, _ text: String, _ author: String) {
        lock.lock(); defer { lock.unlock() }
        playlists.append(Playlist(id: id, name: name, text: text, author: author, songs: [])); save()
    }
    func addToPlaylist(_ id: String, _ files: [String]) {
        lock.lock(); defer { lock.unlock() }
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[i].songs += files; save()
        MPMediaLibrary._default.changed()
    }

    /// A new device's library: six short tunes isim synthesizes (stand-ins for a user's music).
    static func seed() -> [Song] {
        let tunes: [(String, String, String, String, Int, [Int], Double)] = [
            ("Morning Sine", "The Oscillators", "Sine Waves", "Electronic", 1, [60, 64, 67, 72, 67, 64, 62, 65, 69, 72, 69, 65], 0.02),
            ("Square Dance", "The Oscillators", "Sine Waves", "Electronic", 2, [67, 67, 69, 71, 72, 71, 69, 67, 65, 64, 62, 60], 0.08),
            ("Triangle Sunset", "The Oscillators", "Sine Waves", "Electronic", 3, [57, 60, 64, 69, 64, 60, 59, 62, 67, 71, 67, 62], 0.14),
            ("Device Data", "isim Ensemble", "Simulated Sessions", "Ambient", 1, [62, 66, 69, 74, 73, 69, 66, 64, 62, 61, 62, 66], 0.55),
            ("Headless Lullaby", "isim Ensemble", "Simulated Sessions", "Ambient", 2, [72, 71, 69, 67, 69, 71, 72, 74, 72, 69, 67, 65], 0.62),
            ("Render Loop", "isim Ensemble", "Simulated Sessions", "Ambient", 3, [55, 59, 62, 67, 62, 59, 57, 60, 64, 69, 64, 60], 0.70),
        ]
        var out: [Song] = []
        for (i, t) in tunes.enumerated() {
            let rate = 44100.0, note = 0.75
            var pcm = [Float](repeating: 0, count: Int(Double(t.5.count) * note * rate))
            for (k, midi) in t.5.enumerated() {
                let f = 440 * pow(2, Double(midi - 69) / 12), start = Int(Double(k) * note * rate)
                for j in 0..<Int(note * rate) where start + j < pcm.count {
                    let x = Double(j) / rate, env = min(1, x * 40) * exp(-x * 3.2)
                    let v = sin(2 * .pi * f * x) + 0.35 * sin(4 * .pi * f * x) + (i < 3 ? 0.2 * sin(6 * .pi * f * x) : 0)
                    pcm[start + j] += Float(0.32 * env * v)
                }
            }
            let base = String(format: "%02d %@", i + 1, t.0)
            let wav = (dir as NSString).appendingPathComponent(base + ".wav")
            var data = [UInt8]()
            func u32(_ v: Int) { for s in 0..<4 { data.append(UInt8(truncatingIfNeeded: v >> (8 * s))) } }
            func u16(_ v: Int) { for s in 0..<2 { data.append(UInt8(truncatingIfNeeded: v >> (8 * s))) } }
            data += Array("RIFF".utf8); u32(36 + pcm.count * 2); data += Array("WAVEfmt ".utf8); u32(16); u16(1); u16(1); u32(44100); u32(88200); u16(2); u16(16)
            data += Array("data".utf8); u32(pcm.count * 2)
            for v in pcm { u16(Int(Int16(max(-1, min(1, v)) * 32767))) }
            FileManager.default.createFile(atPath: wav, contents: Data(data))
            var file = base + ".wav"
            let m4a = (dir as NSString).appendingPathComponent(base + ".m4a")
            if isim_media_transcode(wav, m4a) != 0 { try? FileManager.default.removeItem(atPath: wav); file = base + ".m4a" }
            out.append(Song(file: file, title: t.0, artist: t.1, album: t.2, albumArtist: t.1, genre: t.3, composer: "isim", track: t.4, year: 2026,
                            duration: Double(pcm.count) / rate, added: Date(), hue: t.6))
        }
        return out
    }
    /// album artwork: a generated cover (gradient of the album's hue, its initials)
    nonisolated(unsafe) static var covers: [String: MPMediaItemArtwork] = [:]
    static func artwork(for s: Song) -> MPMediaItemArtwork? {
        guard let album = s.album, let hue = s.hue else { return nil }
        if let a = covers[album] { return a }
        let art = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { size in
            MainActor.assumeIsolated { UIGraphicsImageRenderer(size: size).image { ctx in
                let a = UIColor(hue: CGFloat(hue), saturation: 0.75, brightness: 0.95, alpha: 1)
                let b = UIColor(hue: CGFloat(hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.55, alpha: 1)
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [a.cgColor, b.cgColor] as CFArray, locations: [0, 1])!
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                let initials = album.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
                let font = UIFont.systemFont(ofSize: size.height * 0.36, weight: .heavy)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.9)]
                let t = initials as NSString, ts = t.size(withAttributes: attrs)
                t.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2), withAttributes: attrs)
            } }
        }
        covers[album] = art
        return art
    }
}

// MARK: - queries

public enum MPMediaPredicateComparison: Int, Sendable { case equalTo = 0, contains }
open class MPMediaPredicate: NSObject, @unchecked Sendable {}
open class MPMediaPropertyPredicate: MPMediaPredicate, @unchecked Sendable {
    public let property: String
    public let value: Any?
    public let comparisonType: MPMediaPredicateComparison
    init(_ v: Any?, _ p: String, _ c: MPMediaPredicateComparison) { value = v; property = p; comparisonType = c }
    public convenience init(value: Any?, forProperty property: String) { self.init(value, property, .equalTo) }
    public convenience init(value: Any?, forProperty property: String, comparisonType: MPMediaPredicateComparison) { self.init(value, property, comparisonType) }
    open class func predicate(withValue value: Any?, forProperty property: String) -> MPMediaPropertyPredicate { MPMediaPropertyPredicate(value, property, .equalTo) }
    open class func predicate(withValue value: Any?, forProperty property: String, comparisonType: MPMediaPredicateComparison) -> MPMediaPropertyPredicate {
        MPMediaPropertyPredicate(value, property, comparisonType)
    }
    func matches(_ e: MPMediaEntity) -> Bool {
        let v = e.value(forProperty: property)
        if let s = value as? String {
            guard let t = v as? String else { return false }
            return comparisonType == .contains ? t.range(of: s, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                : t.compare(s, options: [.caseInsensitive]) == .orderedSame
        }
        if let n = value as? NSNumber, let m = v as? NSNumber {
            if property == MPMediaItemPropertyMediaType { return n.uintValue & m.uintValue != 0 }
            return n == m
        }
        if let n = value as? UInt64, let m = v as? NSNumber { return m.uint64Value == n }
        if let n = value as? Int, let m = v as? NSNumber { return m.intValue == n }
        if let b = value as? Bool, let m = v as? NSNumber { return m.boolValue == b }
        return value == nil && v == nil
    }
}

public enum MPMediaGrouping: Int, Sendable { case title = 0, album, artist, albumArtist, composer, genre, playlist, podcastTitle }
open class MPMediaQuerySection: NSObject, @unchecked Sendable {
    public let title: String
    public let range: NSRange
    init(title: String, range: NSRange) { self.title = title; self.range = range }
}
open class MPMediaQuery: NSObject, @unchecked Sendable {
    open var filterPredicates: Set<MPMediaPredicate>?
    open var groupingType: MPMediaGrouping = .title
    public override init() { filterPredicates = nil }
    public init(filterPredicates: Set<MPMediaPredicate>?) { self.filterPredicates = filterPredicates }
    open func addFilterPredicate(_ predicate: MPMediaPredicate) { filterPredicates = (filterPredicates ?? []).union([predicate]) }
    open func removeFilterPredicate(_ predicate: MPMediaPredicate) { filterPredicates?.remove(predicate) }
    static func grouped(_ g: MPMediaGrouping) -> MPMediaQuery { let q = MPMediaQuery(); q.groupingType = g; return q }
    open class func songs() -> MPMediaQuery { grouped(.title) }
    open class func albums() -> MPMediaQuery { grouped(.album) }
    open class func artists() -> MPMediaQuery { grouped(.artist) }
    open class func genres() -> MPMediaQuery { grouped(.genre) }
    open class func composers() -> MPMediaQuery { grouped(.composer) }
    open class func playlists() -> MPMediaQuery { grouped(.playlist) }
    open class func compilations() -> MPMediaQuery {
        let q = grouped(.album); q.addFilterPredicate(MPMediaPropertyPredicate(value: true, forProperty: MPMediaItemPropertyIsCompilation)); return q
    }
    open class func audiobooks() -> MPMediaQuery {
        let q = grouped(.title); q.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: MPMediaType.audioBook.rawValue), forProperty: MPMediaItemPropertyMediaType)); return q
    }
    open class func podcasts() -> MPMediaQuery {
        let q = grouped(.podcastTitle); q.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: MPMediaType.podcast.rawValue), forProperty: MPMediaItemPropertyMediaType)); return q
    }
    var _authorized: Bool { MPMediaLibrary.authorizationStatus() == .authorized }
    /// the items matching the predicates (nil without media library access, like iOS)
    open var items: [MPMediaItem]? {
        guard _authorized else { return nil }
        let lib = _MusicLibrary.shared
        lib.ensure()
        let preds = (filterPredicates ?? []).compactMap { $0 as? MPMediaPropertyPredicate }
        if groupingType == .playlist {
            let lists = playlistMatches(preds)
            var seen = Set<UInt64>()
            return lists.flatMap(\.items).filter { seen.insert($0.persistentID).inserted }
        }
        let all = lib.songs.map(MPMediaItem.init).filter { i in preds.allSatisfy { $0.matches(i) } }
        return all.sorted { a, b in
            switch groupingType {
            case .album: return (a.albumTitle ?? "", a.albumTrackNumber) < (b.albumTitle ?? "", b.albumTrackNumber)
            case .artist, .albumArtist: return (a.artist ?? "", a.albumTitle ?? "", a.albumTrackNumber) < (b.artist ?? "", b.albumTitle ?? "", b.albumTrackNumber)
            case .genre: return (a.genre ?? "", a.title ?? "") < (b.genre ?? "", b.title ?? "")
            case .composer: return (a.composer ?? "", a.title ?? "") < (b.composer ?? "", b.title ?? "")
            default: return (a.title ?? "").localizedStandardCompare(b.title ?? "") == .orderedAscending
            }
        }
    }
    func playlistMatches(_ preds: [MPMediaPropertyPredicate]) -> [MPMediaPlaylist] {
        _MusicLibrary.shared.playlists.map(MPMediaPlaylist.init).filter { p in
            preds.allSatisfy { pr in pr.property.hasPrefix("playlist") || pr.property == MPMediaPlaylistPropertyName ? pr.matches(p) : p.items.contains { pr.matches($0) } }
        }
    }
    /// the items grouped by the grouping type (albums, artists, ...; playlists for .playlist)
    open var collections: [MPMediaItemCollection]? {
        guard let items else { return nil }
        if groupingType == .playlist { return playlistMatches((filterPredicates ?? []).compactMap { $0 as? MPMediaPropertyPredicate }) }
        guard groupingType != .title else { return items.map { MPMediaItemCollection(items: [$0]) } }
        let prop = MPMediaItemCollection.titleProperty(forGroupingType: groupingType)
        var order: [String] = [], groups: [String: [MPMediaItem]] = [:]
        for i in items {
            let k = i.value(forProperty: prop) as? String ?? ""
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(i)
        }
        return order.map { MPMediaItemCollection(items: groups[$0]!) }
    }
    static func sections(_ titles: [String]) -> [MPMediaQuerySection] {
        var out: [MPMediaQuerySection] = []
        for (i, t) in titles.enumerated() {
            let letter = t.first.map { $0.isLetter ? String($0).uppercased() : "#" } ?? "#"
            if let last = out.last, last.title == letter { out[out.count - 1] = MPMediaQuerySection(title: letter, range: NSRange(location: last.range.location, length: last.range.length + 1)) }
            else { out.append(MPMediaQuerySection(title: letter, range: NSRange(location: i, length: 1))) }
        }
        return out
    }
    open var itemSections: [MPMediaQuerySection]? { items.map { Self.sections($0.map { $0.title ?? "" }) } }
    open var collectionSections: [MPMediaQuerySection]? {
        let prop = MPMediaItemCollection.titleProperty(forGroupingType: groupingType)
        return collections.map { cs in Self.sections(cs.map { ($0 as? MPMediaPlaylist)?.name ?? ($0.representativeItem?.value(forProperty: prop) as? String ?? "") }) }
    }
}

// MARK: - players

public enum MPMusicPlaybackState: Int, Sendable { case stopped = 0, playing, paused, interrupted, seekingForward, seekingBackward }
public enum MPMusicRepeatMode: Int, Sendable { case `default` = 0, none, one, all }
public enum MPMusicShuffleMode: Int, Sendable { case `default` = 0, off, songs, albums }

open class MPMusicPlayerQueueDescriptor: NSObject, @unchecked Sendable {
    open var startItem: MPMediaItem?
    func items() -> [MPMediaItem] { [] }
}
open class MPMusicPlayerMediaItemQueueDescriptor: MPMusicPlayerQueueDescriptor, @unchecked Sendable {
    public let query: MPMediaQuery
    public let itemCollection: MPMediaItemCollection
    public init(query: MPMediaQuery) { self.query = query; itemCollection = MPMediaItemCollection(items: query.items ?? []) }
    public init(itemCollection: MPMediaItemCollection) { query = MPMediaQuery(); self.itemCollection = itemCollection }
    override func items() -> [MPMediaItem] { itemCollection.items }
    open func setStartTime(_ startTime: TimeInterval, for mediaItem: MPMediaItem) {}
    open func setEndTime(_ endTime: TimeInterval, for mediaItem: MPMediaItem) {}
}
/// Apple Music catalog items: isim has no Apple Music catalog, so these queues are empty.
open class MPMusicPlayerStoreQueueDescriptor: MPMusicPlayerQueueDescriptor, @unchecked Sendable {
    open var storeIDs: [String]?
    open var startItemID: String?
    public init(storeIDs: [String]) { self.storeIDs = storeIDs }
    open func setStartTime(_ startTime: TimeInterval, forItemWithStoreID storeID: String) {}
    open func setEndTime(_ endTime: TimeInterval, forItemWithStoreID storeID: String) {}
}
open class MPMusicPlayerPlayParametersQueueDescriptor: MPMusicPlayerQueueDescriptor, @unchecked Sendable {}

open class MPMusicPlayerController: NSObject, @unchecked Sendable {
    static let _system = MPMusicPlayerController(system: true)
    static let _application = MPMusicPlayerController(system: false)
    static let _queue = MPMusicPlayerApplicationController(system: false)
    /// the Music app's player (isim: plays in this app and shows in Control Center)
    open class var systemMusicPlayer: MPMusicPlayerController { _system }
    open class var applicationMusicPlayer: MPMusicPlayerController { _application }
    open class var applicationQueuePlayer: MPMusicPlayerApplicationController { _queue }
    @available(*, deprecated, renamed: "systemMusicPlayer")
    open class var iPodMusicPlayer: MPMusicPlayerController { _system }
    let system: Bool
    init(system: Bool) { self.system = system }

    var queue: [MPMediaItem] = []
    var order: [Int] = []                          // queue indexes in play order (shuffle)
    var position = 0                               // in order
    var player: AVAudioPlayer?
    var notifying = 0
    open private(set) var playbackState: MPMusicPlaybackState = .stopped { didSet { if oldValue != playbackState { post(.MPMusicPlayerControllerPlaybackStateDidChange) } } }
    open var repeatMode: MPMusicRepeatMode = .default
    open var shuffleMode: MPMusicShuffleMode = .default { didSet { reshuffle() } }
    open private(set) var isPreparedToPlay = false
    open var currentPlaybackRate: Float {
        get { playbackState == .playing ? (player?.enableRate == true ? player!.rate : 1) : 0 }
        set { if let p = player { p.enableRate = true; p.rate = newValue }; if newValue == 0 { pause() } else if playbackState != .playing { play() } }
    }

    open func beginGeneratingPlaybackNotifications() { notifying += 1 }
    open func endGeneratingPlaybackNotifications() { notifying = max(0, notifying - 1) }
    func post(_ n: Notification.Name) { if notifying > 0 { NotificationCenter.default.post(name: n, object: self) } }

    open func setQueue(with query: MPMediaQuery) { setQueue(query.items ?? []) }
    open func setQueue(with itemCollection: MPMediaItemCollection) { setQueue(itemCollection.items) }
    open func setQueue(with storeIDs: [String]) {
        NSLog("isim MediaPlayer: Apple Music catalog items cannot play on isim (no catalog); the queue is empty")
        setQueue([])
    }
    open func setQueue(with descriptor: MPMusicPlayerQueueDescriptor) {
        if descriptor is MPMusicPlayerStoreQueueDescriptor { setQueue(with: [String]()); return }
        setQueue(descriptor.items())
        if let s = descriptor.startItem, let i = queue.firstIndex(of: s), let k = order.firstIndex(of: i) { position = k }
    }
    open func prepend(_ descriptor: MPMusicPlayerQueueDescriptor) {
        let add = descriptor.items()
        let at = order.isEmpty ? 0 : order[min(position, order.count - 1)] + 1
        queue.insert(contentsOf: add, at: min(at, queue.count)); reorder()
    }
    open func append(_ descriptor: MPMusicPlayerQueueDescriptor) { queue += descriptor.items(); reorder() }
    func setQueue(_ items: [MPMediaItem]) {
        stopPlayer()
        queue = items; position = 0; reorder(); isPreparedToPlay = false
        playbackState = .stopped
        post(.MPMusicPlayerControllerQueueDidChange)
        post(.MPMusicPlayerControllerNowPlayingItemDidChange)
    }
    func reorder() { order = Array(queue.indices); if shuffleMode == .songs || shuffleMode == .albums { reshuffle() } }
    func reshuffle() {
        let current = order.isEmpty ? nil : order[min(position, order.count - 1)]
        order = Array(queue.indices)
        if shuffleMode == .songs || shuffleMode == .albums {
            order.shuffle()
            if let c = current, let i = order.firstIndex(of: c) { order.swapAt(0, i); position = 0 }
        } else if let c = current { position = c }
    }

    open var nowPlayingItem: MPMediaItem? {
        get { order.isEmpty || position >= order.count ? nil : queue[order[position]] }
        set {
            guard let item = newValue else { stop(); return }
            if let i = queue.firstIndex(of: item), let k = order.firstIndex(of: i) { position = k } else { queue = [item]; reorder(); position = 0 }
            let playing = playbackState == .playing
            stopPlayer()
            if playing { play() }
            post(.MPMusicPlayerControllerNowPlayingItemDidChange)
        }
    }
    open var indexOfNowPlayingItem: Int { order.isEmpty || position >= order.count ? NSNotFound : order[position] }
    open var currentPlaybackTime: TimeInterval {
        get { player?.currentTime ?? 0 }
        set { player?.currentTime = newValue; publish() }
    }

    open func prepareToPlay() { prepareToPlay(completionHandler: { _ in }) }
    open func prepareToPlay(completionHandler: @escaping (Error?) -> Void) {
        let ok = loadCurrent()
        isPreparedToPlay = ok
        DispatchQueue.main.async { completionHandler(ok ? nil : MPError(.notFound)) }
    }
    open func prepareToPlay() async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in prepareToPlay { e in if let e { k.resume(throwing: e) } else { k.resume() } } }
    }
    func loadCurrent() -> Bool {
        guard let item = nowPlayingItem, let url = item.assetURL else { return false }
        if let p = player, p.url == url { return true }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { NSLog("isim MediaPlayer: cannot play %@", url.path); return false }
        p.delegate = delegateProxy
        player = p
        return true
    }
    lazy var delegateProxy = _PlayerDelegate(self)
    open func play() {
        guard loadCurrent(), let p = player else { return }
        installRemoteCommands()
        p.play()
        playbackState = .playing
        if let item = nowPlayingItem { _MusicLibrary.shared.played(item.record.file) }
        publish()
    }
    open func pause() {
        player?.pause()
        if playbackState != .stopped { playbackState = .paused }
        publish()
    }
    open func stop() {
        stopPlayer()
        playbackState = .stopped
        publish()
    }
    func stopPlayer() { player?.stop(); player = nil; isPreparedToPlay = false }
    open func skipToNextItem() { move(+1, wrap: repeatMode == .all) }
    open func skipToPreviousItem() { move(-1, wrap: repeatMode == .all) }
    open func skipToBeginning() { player?.currentTime = 0; publish() }
    open func beginSeekingForward() { playbackState = .seekingForward; player?.enableRate = true; player?.rate = 2 }
    open func beginSeekingBackward() { playbackState = .seekingBackward; player?.currentTime = max(0, (player?.currentTime ?? 0) - 5) }
    open func endSeeking() { player?.rate = 1; playbackState = player?.isPlaying == true ? .playing : .paused }
    func move(_ d: Int, wrap: Bool) {
        guard !order.isEmpty else { return }
        var k = position + d
        if k >= order.count { if wrap { k = 0 } else { stop(); position = order.count; post(.MPMusicPlayerControllerNowPlayingItemDidChange); return } }
        if k < 0 { k = wrap ? order.count - 1 : 0 }
        let playing = playbackState == .playing
        stopPlayer()
        position = k
        post(.MPMusicPlayerControllerNowPlayingItemDidChange)
        if playing { play() } else { publish() }
    }
    func finished() {
        if repeatMode == .one { player?.currentTime = 0; player?.play(); return }
        move(+1, wrap: repeatMode == .all)
    }
    /// the player's song in Control Center / on the lock screen
    func publish() {
        guard let item = nowPlayingItem else { MPNowPlayingInfoCenter.shared.nowPlayingInfo = nil; return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: item.title ?? "", MPMediaItemPropertyPlaybackDuration: item.playbackDuration,
                                   MPNowPlayingInfoPropertyElapsedPlaybackTime: currentPlaybackTime,
                                   MPNowPlayingInfoPropertyPlaybackRate: playbackState == .playing ? 1.0 : 0.0,
                                   MPNowPlayingInfoPropertyPlaybackQueueIndex: indexOfNowPlayingItem, MPNowPlayingInfoPropertyPlaybackQueueCount: queue.count]
        if let a = item.artist { info[MPMediaItemPropertyArtist] = a }
        if let a = item.albumTitle { info[MPMediaItemPropertyAlbumTitle] = a }
        if let a = item.artwork { info[MPMediaItemPropertyArtwork] = a }
        MPNowPlayingInfoCenter.shared.nowPlayingInfo = info
    }
    var remoteInstalled = false
    func installRemoteCommands() {
        guard !remoteInstalled else { return }
        remoteInstalled = true
        let c = MPRemoteCommandCenter.shared()
        _ = c.togglePlayPauseCommand.addTarget { [weak self] _ in guard let self else { return .commandFailed }; if self.playbackState == .playing { self.pause() } else { self.play() }; return .success }
        _ = c.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        _ = c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        _ = c.nextTrackCommand.addTarget { [weak self] _ in self?.skipToNextItem(); return .success }
        _ = c.previousTrackCommand.addTarget { [weak self] _ in self?.skipToPreviousItem(); return .success }
    }
}
final class _PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var owner: MPMusicPlayerController?
    init(_ o: MPMusicPlayerController) { owner = o }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { owner?.finished() }
}

open class MPMusicPlayerControllerQueue: NSObject, @unchecked Sendable {
    weak var owner: MPMusicPlayerController?
    open var items: [MPMediaItem] { owner?.queue ?? [] }
}
open class MPMusicPlayerControllerMutableQueue: MPMusicPlayerControllerQueue, @unchecked Sendable {
    open func insert(_ queueDescriptor: MPMusicPlayerQueueDescriptor, after afterItem: MPMediaItem?) {
        guard let o = owner else { return }
        let at = afterItem.flatMap { o.queue.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        o.queue.insert(contentsOf: queueDescriptor.items(), at: at); o.reorder()
    }
    open func remove(_ item: MPMediaItem) {
        guard let o = owner, let i = o.queue.firstIndex(of: item) else { return }
        o.queue.remove(at: i); o.reorder()
    }
}
open class MPMusicPlayerApplicationController: MPMusicPlayerController, @unchecked Sendable {
    open func perform(queueTransaction: @escaping (MPMusicPlayerControllerMutableQueue) -> Void,
                      completionHandler: @escaping (MPMusicPlayerControllerQueue, Error?) -> Void) {
        let q = MPMusicPlayerControllerMutableQueue(); q.owner = self
        queueTransaction(q)
        post(.MPMusicPlayerControllerQueueDidChange)
        let done = MPMusicPlayerControllerQueue(); done.owner = self
        DispatchQueue.main.async { completionHandler(done, nil) }
    }
}

// MARK: - picker

@objc public protocol MPMediaPickerControllerDelegate: NSObjectProtocol {
    @objc optional func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection)
    @objc optional func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController)
}

/// The library's songs in a sheet: tap to pick (with allowsPickingMultipleItems: check several, then Done).
open class MPMediaPickerController: UIViewController {
    public let mediaTypes: MPMediaType
    open weak var delegate: MPMediaPickerControllerDelegate?
    open var allowsPickingMultipleItems = false
    open var showsCloudItems = true
    open var showsItemsWithProtectedAssets = true
    open var prompt: String?
    var songs: [MPMediaItem] = []
    var selected = Set<Int>()
    var checks: [UIImageView] = []
    let list = UIScrollView()
    public init(mediaTypes: MPMediaType) { self.mediaTypes = mediaTypes; super.init(nibName: nil, bundle: nil) }
    public convenience init() { self.init(mediaTypes: .any) }
    public required init?(coder: NSCoder) { mediaTypes = .any; super.init(coder: coder) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let authorized = MPMediaLibrary.authorizationStatus() == .authorized
        songs = authorized && mediaTypes.contains(.music) ? (MPMediaQuery.songs().items ?? []) : []
        let bar = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 56))
        bar.autoresizingMask = [.flexibleWidth]
        view.addSubview(bar)
        let title = UILabel(frame: CGRect(x: 80, y: 16, width: view.bounds.width - 160, height: 24))
        title.text = prompt ?? "Songs"; title.textAlignment = .center; title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.autoresizingMask = [.flexibleWidth]
        bar.addSubview(title)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal); cancel.titleLabel?.font = .systemFont(ofSize: 17)
        cancel.frame = CGRect(x: 16, y: 12, width: 70, height: 32); cancel.contentHorizontalAlignment = .left
        cancel.accessibilityIdentifier = "media-picker-cancel"
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        bar.addSubview(cancel)
        if allowsPickingMultipleItems {
            let done = UIButton(type: .system)
            done.setTitle("Done", for: .normal); done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            done.frame = CGRect(x: view.bounds.width - 86, y: 12, width: 70, height: 32); done.contentHorizontalAlignment = .right
            done.autoresizingMask = [.flexibleLeftMargin]
            done.accessibilityIdentifier = "media-picker-done"
            done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
            bar.addSubview(done)
        }
        list.frame = CGRect(x: 0, y: 56, width: view.bounds.width, height: view.bounds.height - 56)
        list.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(list)
        if songs.isEmpty {
            let empty = UILabel(frame: CGRect(x: 20, y: 120, width: view.bounds.width - 40, height: 60))
            empty.text = authorized ? "No Songs" : "Allow access to your media library in Settings"
            empty.textAlignment = .center; empty.textColor = .secondaryLabel; empty.numberOfLines = 0
            list.addSubview(empty)
        }
        buildRows()
    }
    func buildRows() {
        let w = view.bounds.width, h: CGFloat = 60
        for (i, s) in songs.enumerated() {
            let row = UIButton(type: .custom)
            row.frame = CGRect(x: 0, y: CGFloat(i) * h, width: w, height: h)
            row.autoresizingMask = [.flexibleWidth]
            row.tag = i
            row.accessibilityIdentifier = "media-picker-" + (s.title ?? "").replacingOccurrences(of: " ", with: "-")
            row.accessibilityLabel = s.title
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            let art = UIImageView(image: s.artwork?.image(at: CGSize(width: 44, height: 44)))
            art.frame = CGRect(x: 16, y: 8, width: 44, height: 44)
            art.layer.cornerRadius = 4; art.clipsToBounds = true
            row.addSubview(art)
            let t = UILabel(frame: CGRect(x: 72, y: 10, width: w - 130, height: 21))
            t.text = s.title; t.font = .systemFont(ofSize: 16)
            row.addSubview(t)
            let a = UILabel(frame: CGRect(x: 72, y: 31, width: w - 130, height: 18))
            a.text = [s.artist, s.albumTitle].compactMap { $0 }.joined(separator: " · "); a.font = .systemFont(ofSize: 13); a.textColor = .secondaryLabel
            row.addSubview(a)
            if allowsPickingMultipleItems {
                let check = UIImageView(image: UIImage(systemName: "plus.circle"))
                check.tintColor = .systemRed
                check.frame = CGRect(x: w - 44, y: 18, width: 24, height: 24)
                check.autoresizingMask = [.flexibleLeftMargin]
                row.addSubview(check)
                checks.append(check)
            }
            let sep = UIView(frame: CGRect(x: 72, y: h - 0.5, width: w - 72, height: 0.5))
            sep.backgroundColor = .separator
            row.addSubview(sep)
            list.addSubview(row)
        }
        list.contentSize = CGSize(width: w, height: CGFloat(songs.count) * h)
    }
    @objc func rowTapped(_ sender: UIButton) {
        if allowsPickingMultipleItems {
            if selected.contains(sender.tag) { selected.remove(sender.tag) } else { selected.insert(sender.tag) }
            checks[sender.tag].image = UIImage(systemName: selected.contains(sender.tag) ? "checkmark.circle.fill" : "plus.circle")
            return
        }
        pick([songs[sender.tag]])
    }
    @objc func doneTapped() { pick(selected.sorted().map { songs[$0] }) }
    @objc func cancelTapped() {
        if let d = delegate, d.responds(to: #selector(MPMediaPickerControllerDelegate.mediaPickerDidCancel(_:))) { d.mediaPickerDidCancel?(self) }
        else { dismiss(animated: true) }
    }
    func pick(_ items: [MPMediaItem]) {
        NSLog("isim MediaPlayer: media picker picked %d item(s)", items.count)
        if let d = delegate, d.responds(to: #selector(MPMediaPickerControllerDelegate.mediaPicker(_:didPickMediaItems:))) {
            d.mediaPicker?(self, didPickMediaItems: MPMediaItemCollection(items: items))
        } else { dismiss(animated: true) }
    }
}
