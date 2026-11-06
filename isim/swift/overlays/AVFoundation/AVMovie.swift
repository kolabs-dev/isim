// QuickTime movies (issue #877, part 3): AVMovie, AVMutableMovie and their tracks, media data storage, writing
// options, fragmented movies and the fragment minder.
//
// Adapted: an AVMutableMovie edits like a composition (it keeps an AVMutableComposition of its tracks' segments,
// so export, readers and players take it the way they take compositions). Writing a movie header writes a
// self-contained movie: isim's movies hold their samples (encoded by the host's ffmpeg); they don't reference
// other files' sample data.
import Foundation
import CoreMedia
import CoreGraphics

public struct AVMovieWritingOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var addMovieHeaderToDestination: AVMovieWritingOptions { [] }
    public static var truncateDestinationToMovieHeaderOnly: AVMovieWritingOptions { AVMovieWritingOptions(rawValue: 1) }
}
public let AVMovieReferenceRestrictionsKey = "AVMovieReferenceRestrictionsKey"
public let AVMovieShouldSupportAliasDataReferencesKey = "AVMovieShouldSupportAliasDataReferencesKey"

/// where a movie's new sample data is written
@objc(AVMediaDataStorage) open class AVMediaDataStorage: NSObject, @unchecked Sendable {
    let _url: URL
    public init(url URL: URL, options: [String: Any]? = nil) { _url = URL; super.init() }
    @available(*, deprecated, renamed: "init(url:options:)")
    public convenience init(URL: URL, options: [String: Any]?) { self.init(url: URL, options: options) }
    open func url() -> URL? { _url }
}

// MARK: - movies

/// A QuickTime movie file (or data): an asset whose tracks are movie tracks
@objc(AVMovie) open class AVMovie: AVAsset, NSCopying, NSMutableCopying, @unchecked Sendable {
    let _movieURL: URL?
    let _movieData: Data?
    var _storage: AVMediaDataStorage?
    /// the movie's file: `url`, or a temporary copy of `data`
    init(_movieURL u: URL?, data: Data?) {
        _movieURL = u; _movieData = data
        var file = u
        if file == nil, let data {
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-movie-\(UUID().uuidString).mov")
            try? data.write(to: tmp)
            file = tmp
        }
        super.init(_url: file)
    }
    public convenience init(url URL: URL, options: [String: Any]? = nil) { self.init(_movieURL: URL, data: nil) }
    public convenience init(url URL: URL) { self.init(url: URL, options: nil) }
    @available(*, deprecated, renamed: "init(url:options:)")
    public convenience init(URL: URL, options: [String: Any]?) { self.init(url: URL, options: options) }
    public convenience init(data: Data, options: [String: Any]? = nil) { self.init(_movieURL: nil, data: data) }
    open class func movieTypes() -> [AVFileType] { [.mov, .mp4, .m4v, .m4a, AVFileType(rawValue: "public.3gpp")] }
    open var url: URL? { _movieURL }
    open var data: Data? { _movieData }
    open var defaultMediaDataStorage: AVMediaDataStorage? { _storage }
    open var canContainMovieFragments: Bool { true }
    open var containsMovieFragments: Bool { false }
    open func `is`(compatibleWithFileType fileType: AVFileType) -> Bool { AVMovie.movieTypes().contains(fileType) }
    open override var tracks: [AVAssetTrack] {
        super.tracks.map { AVMovieTrack(asset: self, id: $0.trackID, type: $0.mediaType, size: $0.naturalSize, fps: $0.nominalFrameRate, range: $0.timeRange) }
    }
    var _movieTracks: [AVMovieTrack] { tracks.compactMap { $0 as? AVMovieTrack } }
    open func loadTrack(withTrackID trackID: CMPersistentTrackID, completionHandler: @escaping @Sendable (AVMovieTrack?, (any Error)?) -> Void) {
        DispatchQueue.global().async { do { try self._check(); completionHandler(self._movieTracks.first { $0.trackID == trackID }, nil) } catch { completionHandler(nil, error) } }
    }
    open func loadTracks(withMediaType mediaType: AVMediaType, completionHandler: @escaping @Sendable ([AVMovieTrack]?, (any Error)?) -> Void) {
        DispatchQueue.global().async { do { try self._check(); completionHandler(self._movieTracks.filter { $0.mediaType == mediaType }, nil) } catch { completionHandler(nil, error) } }
    }
    open func loadTracks(withMediaCharacteristic c: AVMediaCharacteristic, completionHandler: @escaping @Sendable ([AVMovieTrack]?, (any Error)?) -> Void) {
        DispatchQueue.global().async { do { try self._check(); completionHandler(self._movieTracks.filter { $0.hasMediaCharacteristic(c) }, nil) } catch { completionHandler(nil, error) } }
    }
    /// the movie's file data (isim: a self-contained movie of the file type)
    open func makeMovieHeader(fileType: AVFileType) throws -> Data {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory() + "isim-header-\(UUID().uuidString).\(fileType == .mp4 ? "mp4" : "mov")")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try writeHeader(to: tmp, fileType: fileType, options: [])
        return try Data(contentsOf: tmp)
    }
    /// writes the movie to a file (isim: self-contained, with its samples; the options are accepted)
    open func writeHeader(to URL: URL, fileType: AVFileType, options: AVMovieWritingOptions = []) throws {
        try _check()
        guard let src = _url else { throw AVError(.invalidSourceMedia, reason: "the movie has no media") }
        try? FileManager.default.removeItem(at: URL)
        if fileType == .mov || fileType == .mp4 || fileType == .m4v, src.pathExtension.lowercased() == URL.pathExtension.lowercased() {
            try FileManager.default.copyItem(at: src, to: URL)
            return
        }
        try _export(self, to: URL, fileType: fileType)
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { (try? AVMutableMovie(settingsFrom: self, options: nil))?._filled(from: self) ?? AVMutableMovie() }
}

/// exports an asset (a movie or a composition) synchronously
func _export(_ asset: AVAsset, to url: URL, fileType: AVFileType) throws {
    guard let s = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw AVError(.exportFailed) }
    s.outputURL = url; s.outputFileType = fileType
    s._run()
    if s.status != .completed { throw s.error ?? AVError(.exportFailed) }
}

/// A movie whose tracks can be edited: time ranges inserted (from other assets), removed and scaled, tracks added and removed
@objc(AVMutableMovie) open class AVMutableMovie: AVMovie, @unchecked Sendable {
    let _composition = AVMutableComposition()
    var _mtracks: [AVMutableMovieTrack] = []
    var _rate: Float = 1, _volume: Float = 1, _transform = CGAffineTransform.identity
    open var timescale: CMTimeScale = 600
    open var interleavingPeriod = CMTime(value: 1, timescale: 2)
    open var isModified = false
    open override var defaultMediaDataStorage: AVMediaDataStorage? { get { _storage } set { _storage = newValue } }
    init() { super.init(_movieURL: nil, data: nil) }
    init(file: URL?, data: Data?) throws {
        super.init(_movieURL: file, data: data)
        if file != nil || data != nil { let src = AVURLAsset(url: _url!); try src._check(); _filled(from: src) }
        isModified = false
    }
    public convenience init(url URL: URL, options: [String: Any]?, error: ()) throws { try self.init(file: URL, data: nil) }
    @available(*, deprecated, renamed: "init(url:options:error:)")
    public convenience init(URL: URL, options: [String: Any]?, error: ()) throws { try self.init(file: URL, data: nil) }
    public convenience init(data: Data, options: [String: Any]?, error: ()) throws { try self.init(file: nil, data: data) }
    /// an empty movie with another movie's settings (rate, volume, transform, timescale)
    public convenience init(settingsFrom movie: AVMovie?, options: [String: Any]?) throws {
        try self.init(file: nil, data: nil)
        if let m = movie { _rate = m.preferredRate; _volume = m.preferredVolume; _transform = m.preferredTransform }
    }
    @available(*, deprecated, renamed: "init(settingsFrom:options:)")
    public convenience init(settingsFromMovie movie: AVMovie?, options: [String: Any]?) throws { try self.init(settingsFrom: movie, options: options) }
    @discardableResult func _filled(from asset: AVAsset) -> AVMutableMovie {
        for src in asset.tracks where src.mediaType == .video || src.mediaType == .audio {
            guard let t = _addTrack(src.mediaType, id: src.trackID) else { continue }
            try? t._ct.insertTimeRange(src.timeRange, of: src, at: .zero)
            t._sync(from: src)
        }
        return self
    }
    func _addTrack(_ type: AVMediaType, id: CMPersistentTrackID) -> AVMutableMovieTrack? {
        guard let ct = _composition.addMutableTrack(withMediaType: type, preferredTrackID: id) else { return nil }
        let t = AVMutableMovieTrack(movie: self, track: ct)
        _mtracks.append(t)
        return t
    }
    func _changed() { isModified = true; _mtracks.forEach { $0._sync(from: nil) } }

    // MARK: the asset
    override var _comp: AVComposition? { _composition }
    override func _check() {}
    override func _videoSource(at t: Double) -> (URL, Double)? { _composition._videoSource(at: t) }
    open override var tracks: [AVAssetTrack] { _mtracks }
    open override var duration: CMTime { _composition.duration }
    open override var naturalSize: CGSize { _composition.naturalSize }
    open override var isPlayable: Bool { !_mtracks.isEmpty }
    open override var isReadable: Bool { !_mtracks.isEmpty }
    open override var isExportable: Bool { !_mtracks.isEmpty }
    open override var isComposable: Bool { true }
    open override var preferredRate: Float { get { _rate } set { _rate = newValue; isModified = true } }
    open override var preferredVolume: Float { get { _volume } set { _volume = newValue; isModified = true } }
    open override var preferredTransform: CGAffineTransform { get { _transform } set { _transform = newValue; isModified = true } }
    open override func statusOfValue(forKey key: String, error outError: UnsafeMutablePointer<NSError?>?) -> AVKeyValueStatus { .loaded }
    open override func track(withTrackID id: CMPersistentTrackID) -> AVMutableMovieTrack? { _mtracks.first { $0.trackID == id } }
    open func tracks(withMediaCharacteristic c: AVMediaCharacteristic) -> [AVMutableMovieTrack] { _mtracks.filter { $0.hasMediaCharacteristic(c) } }
    open override func loadTrack(withTrackID trackID: CMPersistentTrackID, completionHandler: @escaping @Sendable (AVMutableMovieTrack?, (any Error)?) -> Void) {
        let t = track(withTrackID: trackID); DispatchQueue.global().async { completionHandler(t, nil) }
    }
    open func loadTracks(withMediaType mediaType: AVMediaType, completionHandler: @escaping @Sendable ([AVMutableMovieTrack]?, (any Error)?) -> Void) {
        let t = _mtracks.filter { $0.mediaType == mediaType }; DispatchQueue.global().async { completionHandler(t, nil) }
    }
    open func loadTracks(withMediaCharacteristic c: AVMediaCharacteristic, completionHandler: @escaping @Sendable ([AVMutableMovieTrack]?, (any Error)?) -> Void) {
        let t = tracks(withMediaCharacteristic: c); DispatchQueue.global().async { completionHandler(t, nil) }
    }

    // MARK: editing
    open func unusedTrackID() -> CMPersistentTrackID { (_mtracks.map(\.trackID).max() ?? 0) + 1 }
    open func mutableTrack(compatibleWith track: AVAssetTrack) -> AVMutableMovieTrack? { _mtracks.first { $0.mediaType == track.mediaType } }
    /// a new empty track (video or audio), with another track's settings
    open func addMutableTrack(withMediaType mediaType: AVMediaType, copySettingsFrom track: AVAssetTrack?, options: [String: Any]? = nil) -> AVMutableMovieTrack? {
        guard let t = _addTrack(mediaType, id: unusedTrackID()) else { return nil }
        if let src = track { t._sync(from: src) }
        isModified = true
        return t
    }
    open func addMutableTracksCopyingSettings(from existingTracks: [AVAssetTrack], options: [String: Any]? = nil) -> [AVMutableMovieTrack] {
        existingTracks.compactMap { addMutableTrack(withMediaType: $0.mediaType, copySettingsFrom: $0, options: options) }
    }
    open func removeTrack(_ track: AVMovieTrack) {
        guard let t = track as? AVMutableMovieTrack else { return }
        _composition.removeTrack(t._ct); _mtracks.removeAll { $0 === t }; isModified = true
    }
    /// inserts a time range of every track of an asset (tracks are added as needed); the samples are referenced from
    /// the source (copySampleData: isim's movies are always written self-contained)
    open func insertTimeRange(_ timeRange: CMTimeRange, of asset: AVAsset, at startTime: CMTime, copySampleData: Bool) throws {
        try _composition.insertTimeRange(timeRange, of: asset._comp ?? asset, at: startTime)
        for ct in _composition._tracks where !_mtracks.contains(where: { $0._ct === ct }) {
            let t = AVMutableMovieTrack(movie: self, track: ct)
            if let src = asset.tracks.first(where: { $0.mediaType == ct.mediaType }) { t._sync(from: src) }
            _mtracks.append(t)
        }
        _changed()
    }
    open func insertEmptyTimeRange(_ timeRange: CMTimeRange) { _composition.insertEmptyTimeRange(timeRange); _changed() }
    open func removeTimeRange(_ timeRange: CMTimeRange) { _composition.removeTimeRange(timeRange); _changed() }
    open func scale(_ timeRange: CMTimeRange, toDuration duration: CMTime) { _composition.scaleTimeRange(timeRange, toDuration: duration); _changed() }

    /// writes the edited movie (a self-contained movie of its tracks' segments)
    open override func writeHeader(to URL: URL, fileType: AVFileType, options: AVMovieWritingOptions = []) throws {
        guard !_mtracks.isEmpty else { throw AVError(.noSourceTrack, reason: "the movie has no tracks") }
        try _export(self, to: URL, fileType: fileType)
    }
    open override func copy(with zone: NSZone? = nil) -> Any {
        let m = AVMutableMovie(); m._filled(from: self); return m
    }
}

// MARK: - tracks

/// a segment of a track: the media time range it shows, at a track time range
@objc(AVAssetTrackSegment) open class AVAssetTrackSegment: NSObject, @unchecked Sendable {
    public let isEmpty: Bool
    public let timeMapping: CMTimeMapping
    init(empty: Bool, mapping: CMTimeMapping) { isEmpty = empty; timeMapping = mapping }
}

/// a track of a QuickTime movie
@objc(AVMovieTrack) open class AVMovieTrack: AVAssetTrack, @unchecked Sendable {
    var _alternateGroup = 0
    open var alternateGroupID: Int { _alternateGroup }
    open var mediaPresentationTimeRange: CMTimeRange { timeRange }
    open var mediaDecodeTimeRange: CMTimeRange { timeRange }
    open var mediaDataStorage: AVMediaDataStorage? { (asset as? AVMovie)?._storage }
}

/// A movie track that can be edited (forwarding to its composition track)
@objc(AVMutableMovieTrack) open class AVMutableMovieTrack: AVMovieTrack, @unchecked Sendable {
    let _ct: AVMutableCompositionTrack
    var _enabled = true, _layer = 0, _language: String?, _extendedLanguage: String?, _storage: AVMediaDataStorage?
    var _associations: [(AVMovieTrack, AVAssetTrack.AssociationType)] = []
    open var isModified = false
    open var preferredMediaChunkSize = 1024 * 1024
    open var preferredMediaChunkDuration = CMTime(value: 1, timescale: 1)
    open var preferredMediaChunkAlignment = 0
    open var sampleReferenceBaseURL: URL?
    open var cleanApertureDimensions: CGSize = .zero
    open var productionApertureDimensions: CGSize = .zero
    open var encodedPixelsDimensions: CGSize = .zero
    open var timescale: CMTimeScale { get { _ct.naturalTimeScale } set { _ct.naturalTimeScale = newValue } }
    init(movie: AVMutableMovie, track: AVMutableCompositionTrack) {
        _ct = track
        super.init(asset: movie, id: track.trackID, type: track.mediaType, size: track.naturalSize, fps: track.nominalFrameRate, range: track.timeRange)
    }
    override var _compTrack: AVCompositionTrack? { _ct }
    func _sync(from src: AVAssetTrack?) {
        if let src {
            if _naturalSize == .zero { _naturalSize = src.naturalSize; encodedPixelsDimensions = src.naturalSize; cleanApertureDimensions = src.naturalSize }
            if _nominalFrameRate == 0 { _nominalFrameRate = src.nominalFrameRate }
            if _ct._naturalSize == .zero { _ct._naturalSize = src.naturalSize }
            if _ct._nominalFrameRate == 0 { _ct._nominalFrameRate = src.nominalFrameRate }
        }
        _timeRange = _ct.timeRange
    }
    func _edited() { isModified = true; (asset as? AVMutableMovie)?._changed() }
    open override var alternateGroupID: Int { get { _alternateGroup } set { _alternateGroup = newValue } }
    open override var isEnabled: Bool { get { _enabled } set { _enabled = newValue } }
    open override var preferredTransform: CGAffineTransform { get { _ct.preferredTransform } set { _ct.preferredTransform = newValue } }
    open override var preferredVolume: Float { get { _ct.preferredVolume } set { _ct.preferredVolume = newValue } }
    open override var languageCode: String? { get { _language } set { _language = newValue } }
    open var extendedLanguageTag: String? { get { _extendedLanguage } set { _extendedLanguage = newValue } }
    open var layer: Int { get { _layer } set { _layer = newValue } }
    open override var mediaDataStorage: AVMediaDataStorage? { get { _storage } set { _storage = newValue } }
    open var naturalTimeScale: CMTimeScale { _ct.naturalTimeScale }
    open var isSelfContained: Bool { true }
    open var hasProtectedContent: Bool { false }
    open var requiresFrameReordering: Bool { false }
    open var hasAudioSampleDependencies: Bool { false }
    open var canProvideSampleCursors: Bool { false }
    open var totalSampleDataLength: Int64 { Int64(max(0, timeRange.duration.seconds) * Double(estimatedDataRate) / 8) }
    open override var estimatedDataRate: Float { mediaType == .video ? 2_000_000 : 128_000 }
    open var formatDescriptions: [Any] { [] }
    open var segments: [AVAssetTrackSegment] { _ct.segments.map { AVAssetTrackSegment(empty: $0.isEmpty, mapping: $0.timeMapping) } }
    open func segment(forTrackTime trackTime: CMTime) -> AVAssetTrackSegment? {
        _ct.segment(forTrackTime: trackTime).map { AVAssetTrackSegment(empty: $0.isEmpty, mapping: $0.timeMapping) }
    }
    open func samplePresentationTime(forTrackTime trackTime: CMTime) -> CMTime {
        guard let s = _ct.segment(forTrackTime: trackTime), !s.isEmpty else { return .invalid }
        let m = s.timeMapping, scale = m.source.duration.seconds / max(1e-9, m.target.duration.seconds)
        return CMTime(seconds: m.source.start.seconds + (trackTime - m.target.start).seconds * scale, preferredTimescale: naturalTimeScale)
    }
    open var availableTrackAssociationTypes: [AVAssetTrack.AssociationType] { Array(Set(_associations.map(\.1))) }
    open func associatedTracks(ofType trackAssociationType: AVAssetTrack.AssociationType) -> [AVAssetTrack] {
        _associations.filter { $0.1 == trackAssociationType }.map(\.0)
    }
    open func addTrackAssociation(to movieTrack: AVMovieTrack, type trackAssociationType: AVAssetTrack.AssociationType) {
        guard !_associations.contains(where: { $0.0 === movieTrack && $0.1 == trackAssociationType }) else { return }
        _associations.append((movieTrack, trackAssociationType)); isModified = true
    }
    open func removeTrackAssociation(to movieTrack: AVMovieTrack, type trackAssociationType: AVAssetTrack.AssociationType) {
        _associations.removeAll { $0.0 === movieTrack && $0.1 == trackAssociationType }; isModified = true
    }
    /// edits, as a composition track's
    open func insertTimeRange(_ timeRange: CMTimeRange, of track: AVAssetTrack, at startTime: CMTime, copySampleData: Bool) throws {
        try _ct.insertTimeRange(timeRange, of: track, at: startTime)
        _sync(from: track); _edited()
    }
    open func insertEmptyTimeRange(_ timeRange: CMTimeRange) { _ct.insertEmptyTimeRange(timeRange); _edited() }
    open func removeTimeRange(_ timeRange: CMTimeRange) { _ct.removeTimeRange(timeRange); _edited() }
    open func scaleTimeRange(_ timeRange: CMTimeRange, toDuration duration: CMTime) { _ct.scaleTimeRange(timeRange, toDuration: duration); _edited() }
    /// media appended to the media data storage (isim's tracks take media from other assets only: false)
    open func insertMediaTimeRange(_ mediaTimeRange: CMTimeRange, into trackTimeRange: CMTimeRange) -> Bool { false }
    /// appends sample data to the track's storage (not available: isim's movie tracks take media from other assets)
    open func append(_ sampleBuffer: CMSampleBuffer, decodeTime outDecodeTime: UnsafeMutablePointer<CMTime>?, presentationTime outPresentationTime: UnsafeMutablePointer<CMTime>?) throws {
        throw AVError(.operationNotAllowed, reason: "isim's movie tracks take media from other assets (insertTimeRange); appending sample buffers is not supported")
    }
    open func replaceFormatDescription(_ formatDescription: CMFormatDescription, with newFormatDescription: CMFormatDescription) { isModified = true }
}

// MARK: - fragmented movies

/// A movie that may grow while it is open (isim: a movie read once, with no fragments)
@objc(AVFragmentedMovie) open class AVFragmentedMovie: AVMovie, @unchecked Sendable {
    public static let containsMovieFragmentsDidChangeNotification = Notification.Name("AVFragmentedMovieContainsMovieFragmentsDidChangeNotification")
    public static let durationDidChangeNotification = Notification.Name("AVFragmentedMovieDurationDidChangeNotification")
    public static let wasDefragmentedNotification = Notification.Name("AVFragmentedMovieWasDefragmentedNotification")
    open override var tracks: [AVAssetTrack] {
        super.tracks.map { AVFragmentedMovieTrack(asset: self, id: $0.trackID, type: $0.mediaType, size: $0.naturalSize, fps: $0.nominalFrameRate, range: $0.timeRange) }
    }
    var _fragmentedTracks: [AVFragmentedMovieTrack] { tracks.compactMap { $0 as? AVFragmentedMovieTrack } }
    open override func loadTrack(withTrackID trackID: CMPersistentTrackID, completionHandler: @escaping @Sendable (AVFragmentedMovieTrack?, (any Error)?) -> Void) {
        DispatchQueue.global().async { completionHandler(self._fragmentedTracks.first { $0.trackID == trackID }, nil) }
    }
    open func loadTracks(withMediaType mediaType: AVMediaType, completionHandler: @escaping @Sendable ([AVFragmentedMovieTrack]?, (any Error)?) -> Void) {
        DispatchQueue.global().async { completionHandler(self._fragmentedTracks.filter { $0.mediaType == mediaType }, nil) }
    }
    open func loadTracks(withMediaCharacteristic c: AVMediaCharacteristic, completionHandler: @escaping @Sendable ([AVFragmentedMovieTrack]?, (any Error)?) -> Void) {
        DispatchQueue.global().async { completionHandler(self._fragmentedTracks.filter { $0.hasMediaCharacteristic(c) }, nil) }
    }
}
@objc(AVFragmentedMovieTrack) open class AVFragmentedMovieTrack: AVMovieTrack, @unchecked Sendable {
    public static let timeRangeDidChangeNotification = Notification.Name("AVFragmentedMovieTrackTimeRangeDidChangeNotification")
    public static let segmentsDidChangeNotification = Notification.Name("AVFragmentedMovieTrackSegmentsDidChangeNotification")
}
/// Checks fragmented movies for new fragments every `mindingInterval` seconds (isim's movies don't grow: kept)
@objc(AVFragmentedMovieMinder) open class AVFragmentedMovieMinder: NSObject, @unchecked Sendable {
    open var mindingInterval: TimeInterval
    open private(set) var movies: [AVFragmentedMovie] = []
    public init(movie: AVFragmentedMovie, mindingInterval: TimeInterval) { self.mindingInterval = mindingInterval; movies = [movie]; super.init() }
    open func add(_ movie: AVFragmentedMovie) { if !movies.contains(where: { $0 === movie }) { movies.append(movie) } }
    open func remove(_ movie: AVFragmentedMovie) { movies.removeAll { $0 === movie } }
}

// MARK: - track associations (all asset tracks)
extension AVAssetTrack {
    /// how one track refers to another
    public struct AssociationType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let audioFallback = Self(rawValue: "fall")
        public static let chapterList = Self(rawValue: "chap")
        public static let forcedSubtitlesOnly = Self(rawValue: "forc")
        public static let selectionFollower = Self(rawValue: "folw")
        public static let timecode = Self(rawValue: "tmcd")
        public static let metadataReferent = Self(rawValue: "cdsc")
        public static let renderMetadataSource = Self(rawValue: "cdep")
    }
}

// MARK: - Objective-C (AVEditing.h)
extension AVMovie {
    @objc(movieTypes) class func _objc_movieTypes() -> [String] { movieTypes().map(\.rawValue) }
    @objc(movieWithURL:options:) class func _objc_movie(_ u: URL, _ o: [String: Any]?) -> AVMovie { AVMovie(url: u, options: o) }
    @objc(URL) var _objc_url: URL? { url }
    @objc(data) var _objc_data: Data? { data }
    @objc(isCompatibleWithFileType:) func _objc_compatible(_ t: String) -> Bool { self.is(compatibleWithFileType: AVFileType(rawValue: t)) }
    @objc(writeMovieHeaderToURL:fileType:options:error:) func _objc_write(_ u: URL, _ t: String, _ o: UInt) throws {
        try writeHeader(to: u, fileType: AVFileType(rawValue: t), options: AVMovieWritingOptions(rawValue: o))
    }
}
extension AVMovieTrack {
    @objc(alternateGroupID) var _objc_alternateGroup: Int { alternateGroupID }
}
extension AVMutableMovie {
    @objc(movieWithURL:options:error:) class func _objc_mutableMovie(_ u: URL, _ o: [String: Any]?) throws -> AVMutableMovie { try AVMutableMovie(url: u, options: o, error: ()) }
    @objc(isModified) var _objc_modified: Bool { isModified }
    @objc(setModified:) func _objc_setModified(_ v: Bool) { isModified = v }
    @objc(unusedTrackID) func _objc_unused() -> CMPersistentTrackID { unusedTrackID() }
    @objc(removeTrack:) func _objc_remove(_ t: AVMovieTrack) { removeTrack(t) }
}
extension AVMutableMovieTrack {
    @objc(isEnabled) var _objc_enabled: Bool { isEnabled }
    @objc(setEnabled:) func _objc_setEnabled(_ v: Bool) { isEnabled = v }
    @objc(layer) var _objc_layer: Int { layer }
    @objc(setLayer:) func _objc_setLayer(_ v: Int) { layer = v }
}
