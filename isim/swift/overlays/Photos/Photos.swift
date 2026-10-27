// isim Photos (self-authored, iOS API names): the device photo library ($ISIM_DATA/Media, shared with UIKit's
// UIImagePickerController and UIImageWriteToSavedPhotosAlbum; seeded with six sample pictures on first use), the
// photo library permission (iOS 17/18 alert: Limit Access… / Allow Full Access / Don't Allow, and the add-only
// alert), PHAsset fetching, PHImageManager image and video requests, PHAssetChangeRequest saving (photos and videos),
// user albums (PHAssetCollectionChangeRequest) and PHAssetResourceManager.
// Live Photos (LivePhoto.swift) and edits (Editing.swift). Adapted: no iCloud, shared albums or folders (PHCollectionList).
// Automation: ISIM_PHOTOS_PERMISSION=allow|limited|deny answers without the alert (limited selects nothing).
import UIKit

@_silgen_name("_isim_photos_seed") func _isimPhotosSeed()
/// UIKit's UISaveVideoAtPathToSavedPhotosAlbum path: copies a movie in with its poster frame; 1 when saved
@_silgen_name("_isim_photos_add_video") func _isimPhotosAddVideo(_ src: UnsafePointer<CChar>, _ id: UnsafePointer<CChar>, _ created: Double, _ app: UnsafePointer<CChar>) -> Int32

@objc public enum PHAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized, limited }
@objc public enum PHAccessLevel: Int, Sendable { case addOnly = 1, readWrite = 2 }
@objc public enum PHAssetMediaType: Int, Sendable { case unknown = 0, image, video, audio }
public struct PHAssetMediaSubtype: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let photoPanorama = PHAssetMediaSubtype(rawValue: 1), photoHDR = PHAssetMediaSubtype(rawValue: 2)
    public static let photoScreenshot = PHAssetMediaSubtype(rawValue: 4), photoLive = PHAssetMediaSubtype(rawValue: 8)
    public static let photoDepthEffect = PHAssetMediaSubtype(rawValue: 16)
}
@objc public enum PHAssetSourceType: UInt, Sendable { case typeUserLibrary = 1, typeCloudShared = 2, typeiTunesSynced = 4 }
@objc public enum PHImageContentMode: Int, Sendable { case aspectFit = 0, aspectFill = 1
    public static var `default`: PHImageContentMode { .aspectFit } }
@objc public enum PHImageRequestOptionsDeliveryMode: Int, Sendable { case opportunistic = 0, highQualityFormat, fastFormat }
@objc public enum PHImageRequestOptionsResizeMode: Int, Sendable { case none = 0, fast, exact }
@objc public enum PHImageRequestOptionsVersion: Int, Sendable { case current = 0, unadjusted, original }
@objc public enum PHAssetResourceType: Int, Sendable {
    case photo = 1, video, audio, alternatePhoto, fullSizePhoto, fullSizeVideo, adjustmentData, adjustmentBasePhoto, pairedVideo, fullSizePairedVideo
    case adjustmentBasePairedVideo, adjustmentBaseVideo
    case photoProxy = 19
}
@objc public enum PHAssetCollectionType: Int, Sendable { case album = 1, smartAlbum = 2, moment = 3 }
@objc public enum PHCollectionEditOperation: Int, Sendable {
    case deleteContent = 1, removeContent = 2, addContent = 3, createContent = 4, rearrangeContent = 5, delete = 6, rename = 7
}
@objc public enum PHAssetCollectionSubtype: Int, Sendable {
    case albumRegular = 2, albumSyncedEvent = 3, albumSyncedFaces = 4, albumSyncedAlbum = 5, albumImported = 6
    case albumMyPhotoStream = 100, albumCloudShared = 101
    case smartAlbumGeneric = 200, smartAlbumPanoramas = 201, smartAlbumVideos = 202, smartAlbumFavorites = 203, smartAlbumTimelapses = 204
    case smartAlbumAllHidden = 205, smartAlbumRecentlyAdded = 206, smartAlbumBursts = 207, smartAlbumSlomoVideos = 208
    case smartAlbumUserLibrary = 209, smartAlbumSelfPortraits = 210, smartAlbumScreenshots = 211, smartAlbumDepthEffect = 212
    case smartAlbumLivePhotos = 213, smartAlbumAnimated = 214, smartAlbumLongExposures = 215, smartAlbumUnableToUpload = 216
    case smartAlbumRAW = 217, smartAlbumCinematic = 218, smartAlbumSpatial = 219
    case any = 9223372036854775807
}

public typealias PHImageRequestID = Int32
public let PHInvalidImageRequestID: PHImageRequestID = 0
public let PHImageManagerMaximumSize = CGSize(width: -1, height: -1)
public let PHImageResultIsDegradedKey = "PHImageResultIsDegradedKey"
public let PHImageResultRequestIDKey = "PHImageResultRequestIDKey"
public let PHImageCancelledKey = "PHImageCancelledKey"
public let PHImageResultIsInCloudKey = "PHImageResultIsInCloudKey"
public let PHImageErrorKey = "PHImageErrorKey"
public let PHPhotosErrorDomain = "PHPhotosErrorDomain"
public let PHLocalIdentifierNotFound = "Not Found"

public struct PHPhotosError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case internalError = -1, userCancelled = 3072, libraryVolumeOffline = 3114, relinquishingLibraryBundleToWriter = 3142
        case switchingSystemPhotoLibrary = 3143, networkAccessRequired = 3164, networkError = 3169, identifierNotFound = 3201
        case multipleIdentifiersFound = 3202, changeNotSupported = 3300, operationInterrupted = 3301, invalidResource = 3302
        case missingResource = 3303, notEnoughSpace = 3305, requestNotSupportedForAsset = 3306, accessRestricted = 3310
        case accessUserDenied = 3311, libraryInFileProviderSyncRoot = 5423, persistentChangeTokenExpired = 3105
        case persistentChangeDetailsUnavailable = 3210, invalid = -2
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { PHPhotosErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? { code == .accessUserDenied ? "The user has denied this app access to their photo library." : "The operation couldn’t be completed. (PHPhotosErrorDomain error \(code.rawValue).)" }
    public static var accessUserDenied: Code { .accessUserDenied }
}

// MARK: - Library store (shared format with UIKit's UIPhotoLibrary.m)

struct _PHRecord {
    var id: String, file: String, created: Double, width: Int, height: Int, favorite: Bool, app: String
    /// videos (UISaveVideoAtPathToSavedPhotosAlbum): kind "video", their duration and a poster frame (PNG)
    var kind = "", duration = 0.0, poster = ""
    /// Live Photos: the paired movie; edits: the original file and the adjustments' plist (paths in Media), when modified
    var live = "", originalFile = "", adjustment = "", modified = 0.0
    var isVideo: Bool { kind == "video" }
    init(_ d: [String: Any]) {
        kind = d["kind"] as? String ?? ""; duration = (d["duration"] as? NSNumber)?.doubleValue ?? 0; poster = d["poster"] as? String ?? ""
        live = d["live"] as? String ?? ""; originalFile = d["original"] as? String ?? ""; adjustment = d["adjustment"] as? String ?? ""
        modified = (d["modified"] as? NSNumber)?.doubleValue ?? 0
        id = d["id"] as? String ?? ""; file = d["file"] as? String ?? ""
        created = (d["created"] as? NSNumber)?.doubleValue ?? 0
        width = (d["width"] as? NSNumber)?.integerValue ?? 0; height = (d["height"] as? NSNumber)?.integerValue ?? 0
        favorite = (d["favorite"] as? NSNumber)?.boolValue ?? false; app = d["app"] as? String ?? ""
    }
    var dict: [String: Any] {
        var d: [String: Any] = ["id": id, "file": file, "created": NSNumber(value: created), "width": NSNumber(value: width), "height": NSNumber(value: height),
                                "favorite": NSNumber(value: favorite), "app": app]
        if isVideo { d["kind"] = kind; d["duration"] = NSNumber(value: duration); d["poster"] = poster }
        if !live.isEmpty { d["live"] = live }
        if !originalFile.isEmpty { d["original"] = originalFile; d["adjustment"] = adjustment }
        if modified > 0 { d["modified"] = NSNumber(value: modified) }
        return d
    }
}

enum _PHStore {
    static var media: String { (_Privacy.dataDir as NSString).appendingPathComponent("Media") }
    static var indexPath: String { (media as NSString).appendingPathComponent("PhotoData/Photos.plist") }
    static func index() -> [String: Any] {
        _isimPhotosSeed()
        guard let d = FileManager.default.contents(atPath: indexPath),
              let p = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: Any] else { return [:] }
        return p
    }
    static func records() -> [_PHRecord] { ((index()["assets"] as? [[String: Any]]) ?? []).map(_PHRecord.init) }
    static func write(_ idx: [String: Any]) {
        guard let d = try? PropertyListSerialization.data(fromPropertyList: idx, format: .xml, options: 0) else { return }
        FileManager.default.createFile(atPath: indexPath, contents: d, attributes: nil)
    }
    static func path(_ r: _PHRecord) -> String { (media as NSString).appendingPathComponent(r.file) }
    /// user albums: {id, title, assets (identifiers, in the album's order), created}
    static func albums() -> [_PHAlbum] { ((index()["albums"] as? [[String: Any]]) ?? []).map(_PHAlbum.init) }
    static func updateAlbums(_ body: (inout [_PHAlbum]) -> Void) {
        var idx = index()
        var albums = ((idx["albums"] as? [[String: Any]]) ?? []).map(_PHAlbum.init)
        body(&albums)
        idx["albums"] = albums.map(\.dict)
        write(idx)
    }
    /// the picture an image request shows: the photo, or a video's poster frame
    static func imagePath(_ r: _PHRecord) -> String { r.isVideo ? (media as NSString).appendingPathComponent(r.poster) : path(r) }
    static func update(_ body: (inout [_PHRecord]) -> Void) {
        var idx = index()
        var recs = ((idx["assets"] as? [[String: Any]]) ?? []).map(_PHRecord.init)
        body(&recs)
        idx["assets"] = recs.map(\.dict)
        write(idx)
    }
    /// writes image data as a new asset; returns its record
    static func add(_ data: Data, ext: String, width: Int, height: Int, created: Date, id: String? = nil) -> _PHRecord? {
        var idx = index()
        let n = (idx["next"] as? NSNumber)?.integerValue ?? 1
        let name = String(format: "IMG_%04d.%@", n, ext)
        let dir = _Privacy.deviceDir("Media/DCIM/100APPLE")
        guard FileManager.default.createFile(atPath: (dir as NSString).appendingPathComponent(name), contents: data, attributes: nil) else { return nil }
        let r = _PHRecord(["id": id ?? "\(UUID().uuidString)/L0/001", "file": "DCIM/100APPLE/\(name)", "created": created.timeIntervalSince1970,
                           "width": width, "height": height, "favorite": false, "app": _Privacy.bundleID])
        var assets = (idx["assets"] as? [[String: Any]]) ?? []
        assets.append(r.dict)
        idx["assets"] = assets; idx["next"] = n + 1
        write(idx)
        return r
    }
}

struct _PHAlbum {
    var id: String, title: String, assets: [String], created: Double
    init(id: String, title: String) { self.id = id; self.title = title; assets = []; created = Date().timeIntervalSince1970 }
    init(_ d: [String: Any]) {
        id = d["id"] as? String ?? ""; title = d["title"] as? String ?? ""; assets = d["assets"] as? [String] ?? []
        created = (d["created"] as? NSNumber)?.doubleValue ?? 0
    }
    var dict: [String: Any] { ["id": id, "title": title, "assets": assets, "created": NSNumber(value: created)] }
}

// MARK: - Authorization

enum _PHAuth {
    static var status: PHAuthorizationStatus { _Privacy.stored("photos").flatMap { PHAuthorizationStatus(rawValue: $0) } ?? .notDetermined }
    static var addStatus: PHAuthorizationStatus {
        let s = status
        if s == .authorized || s == .limited { return .authorized }
        return _Privacy.stored("photosAdd").flatMap { PHAuthorizationStatus(rawValue: $0) } ?? .notDetermined
    }
    /// identifiers a limited-access app may see (selected by the user, plus the assets it created)
    static var limited: Set<String> {
        get { Set((UserDefaults.standard.array(forKey: "_ISIMPrivacy.photos.limited") as? [String]) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: "_ISIMPrivacy.photos.limited"); UserDefaults.standard.synchronize() }
    }
    static func visible() -> [_PHRecord] {
        switch status {
        case .authorized: return _PHStore.records()
        case .limited: let ids = limited; return _PHStore.records().filter { ids.contains($0.id) }
        default: return []
        }
    }
}

public protocol PHPhotoLibraryChangeObserver: AnyObject { func photoLibraryDidChange(_ changeInstance: PHChange) }
public protocol PHPhotoLibraryAvailabilityObserver: AnyObject { func photoLibraryDidBecomeUnavailable(_ photoLibrary: PHPhotoLibrary) }

@objc(PHChange) open class PHChange: NSObject, @unchecked Sendable {
    @objc let changedIDs: Set<String>
    @objc init(_ ids: Set<String>) { changedIDs = ids }
    open func changeDetails<T: PHObject>(for object: T) -> PHObjectChangeDetails<T>? { changedIDs.contains(object.localIdentifier) ? PHObjectChangeDetails(object) : nil }
    open func changeDetails<T: PHObject>(for fetchResult: PHFetchResult<T>) -> PHFetchResultChangeDetails<T>? { PHFetchResultChangeDetails(fetchResult) }
}
open class PHObjectChangeDetails<T: PHObject>: NSObject, @unchecked Sendable {
    let before: T
    init(_ o: T) { before = o }
    open var objectBeforeChanges: T { before }
    open var objectAfterChanges: T? { before }
    open var assetContentChanged: Bool { true }
    open var objectWasDeleted: Bool { false }
}
open class PHFetchResultChangeDetails<T: PHObject>: NSObject, @unchecked Sendable {
    let before: PHFetchResult<T>
    let after: PHFetchResult<T>
    init(_ r: PHFetchResult<T>) { before = r; after = r.refetched() }
    open var fetchResultBeforeChanges: PHFetchResult<T> { before }
    open var fetchResultAfterChanges: PHFetchResult<T> { after }
    open var hasIncrementalChanges: Bool { false }
    open var removedIndexes: IndexSet? { nil }
    open var insertedIndexes: IndexSet? { nil }
    open var changedIndexes: IndexSet? { nil }
    open var hasMoves: Bool { false }
}

@objc(PHPhotoLibrary) open class PHPhotoLibrary: NSObject, @unchecked Sendable {
    @objc static let sharedLibrary = PHPhotoLibrary()
    var observers: [() -> PHPhotoLibraryChangeObserver?] = []
    @objc(sharedPhotoLibrary) open class func shared() -> PHPhotoLibrary { sharedLibrary }
    @objc open var unavailabilityReason: Error? { nil }

    @objc open class func authorizationStatus() -> PHAuthorizationStatus {
        let s = _PHAuth.status
        return s == .limited ? .authorized : s                  // the old API reports limited as authorized, like iOS
    }
    @objc(authorizationStatusForAccessLevel:) open class func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        accessLevel == .addOnly ? _PHAuth.addStatus : _PHAuth.status
    }
    @objc open class func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
        requestAuthorization(for: .readWrite) { s in handler(s == .limited ? .authorized : s) }
    }
    @objc(requestAuthorizationForAccessLevel:handler:)
    open class func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void) {
        let reply: (PHAuthorizationStatus) -> Void = { s in _Privacy.reply { handler(s) } }
        let current = authorizationStatus(for: accessLevel)
        if current != .notDetermined { reply(current); return }
        let key = accessLevel == .addOnly ? "NSPhotoLibraryAddUsageDescription" : "NSPhotoLibraryUsageDescription"
        guard let purpose = _Privacy.usage(key, "Photos") else { reply(.denied); return }
        _Privacy.onMain {
            func answer(_ s: PHAuthorizationStatus) {
                _Privacy.store(accessLevel == .addOnly ? "photosAdd" : "photos", s.rawValue)
                NSLog("isim Photos: %@ access %@ for %@", accessLevel == .addOnly ? "add-only" : "library",
                      s == .authorized ? "full" : s == .limited ? "limited" : "denied", _Privacy.appName)
                reply(s)
            }
            if let sc = _Privacy.scripted("PHOTOS") {
                switch sc {
                case "deny", "denied", "no", "0": answer(.denied)
                case "limited": answer(accessLevel == .addOnly ? .authorized : .limited)
                default: answer(.authorized)
                }
                return
            }
            if accessLevel == .addOnly {
                _Privacy.alert("“\(_Privacy.appName)” Would Like to Add to your Photos", purpose, [("Don’t Allow", .default), ("Allow", .default)]) {
                    answer($0 == 1 ? .authorized : .denied)
                }
                return
            }
            let ios17 = _Privacy.osMajor >= 17
            _Privacy.alert("“\(_Privacy.appName)” Would Like to Access Your Photos", purpose,
                           [(ios17 ? "Limit Access…" : "Select Photos…", .default), (ios17 ? "Allow Full Access" : "Allow Access to All Photos", .default), ("Don’t Allow", .cancel)]) { i in
                switch i {
                case 0:
                    _PHSelection.present(selected: []) { ids in
                        _PHAuth.limited = ids
                        answer(.limited)
                    }
                case 1: answer(.authorized)
                default: answer(.denied)
                }
            }
        }
    }
    @nonobjc open class func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        await withCheckedContinuation { k in requestAuthorization(for: accessLevel) { k.resume(returning: $0) } }
    }

    open func register(_ observer: PHPhotoLibraryChangeObserver) { observers.append { [weak observer] in observer } }
    open func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) { observers.removeAll { $0() === observer || $0() == nil } }
    open func register(_ observer: PHPhotoLibraryAvailabilityObserver) {}
    open func unregisterAvailabilityObserver(_ observer: PHPhotoLibraryAvailabilityObserver) {}

    /// iOS 14+: lets a limited-access app change its selection
    @objc(presentLimitedLibraryPickerFromViewController:) @MainActor open func presentLimitedLibraryPicker(from controller: UIViewController) {
        presentLimitedLibraryPicker(from: controller) { _ in }
    }
    @objc(presentLimitedLibraryPickerFromViewController:completionHandler:)
    @MainActor open func presentLimitedLibraryPicker(from controller: UIViewController, completionHandler: @escaping ([String]) -> Void) {
        guard _PHAuth.status == .limited else { completionHandler([]); return }
        let before = _PHAuth.limited
        _PHSelection.present(selected: before) { ids in
            _PHAuth.limited = ids
            self.notify(ids.symmetricDifference(before))
            completionHandler(Array(ids.subtracting(before)))
        }
    }

    @objc func notify(_ ids: Set<String>) {
        let change = PHChange(ids)
        for o in observers { if let ob = o() { DispatchQueue.global().async { ob.photoLibraryDidChange(change) } } }
    }

    // MARK: changes
    @objc open func performChanges(_ changeBlock: @escaping () -> Void, completionHandler: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global().async {
            do { try self.performChangesAndWait(changeBlock); completionHandler?(true, nil) }
            catch { completionHandler?(false, error) }
        }
    }
    @nonobjc open func performChanges(_ changeBlock: @escaping @Sendable () -> Void) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            performChanges(changeBlock) { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    @objc(performChangesAndWait:error:) open func performChangesAndWait(_ changeBlock: () -> Void) throws {
        _PHChanges.begin()
        changeBlock()
        let reqs = _PHChanges.end()
        if reqs.isEmpty { return }
        let needsRead = reqs.contains { !($0 is PHAssetCreationRequest || ($0 is PHAssetChangeRequest && ($0 as! PHAssetChangeRequest).creating)) }
        // albums need full (or limited) library access, as on iOS
        let ok = needsRead ? (_PHAuth.status == .authorized || _PHAuth.status == .limited) : _PHAuth.addStatus == .authorized
        guard ok else { throw PHPhotosError(.accessUserDenied) }
        var changed = Set<String>()
        var deleteIDs: [String] = []
        for r in reqs {
            if let c = r as? PHAssetChangeRequest {
                if c.creating, let video = c.videoFile {
                    let id = c.placeholder.localIdentifier
                    guard _isimPhotosAddVideo(video.path, id, (c.creationDate ?? Date()).timeIntervalSince1970, _Privacy.bundleID) == 1 else {
                        throw PHPhotosError(.invalidResource)
                    }
                    if c.isFavorite { _PHStore.update { recs in if let i = recs.firstIndex(where: { $0.id == id }) { recs[i].favorite = true } } }
                    if _PHAuth.status == .limited { _PHAuth.limited = _PHAuth.limited.union([id]) }
                    changed.insert(id)
                    NSLog("isim Photos: saved video %@ to the photo library", video.lastPathComponent)
                } else if c.creating {
                    // image encoding draws with the host renderer, which belongs to the main thread
                    let payload = Thread.isMainThread ? c.payload() : DispatchQueue.main.sync { c.payload() }
                    guard let (data, ext, w, h) = payload, let rec = _PHStore.add(data, ext: ext, width: w, height: h, created: c.creationDate ?? Date(), id: c.placeholder.localIdentifier) else {
                        throw PHPhotosError(.invalidResource)
                    }
                    c.placeholder.localIdentifier = rec.id
                    if let movie = c.pairedVideo { try _PHStore.pairVideo(rec.id, movie) }
                    if let out = c.contentEditingOutput { try _PHStore.applyEdit(rec.id, out) }
                    if c.isFavorite { _PHStore.update { recs in if let i = recs.firstIndex(where: { $0.id == rec.id }) { recs[i].favorite = true } } }
                    if _PHAuth.status == .limited { _PHAuth.limited = _PHAuth.limited.union([rec.id]) }
                    changed.insert(rec.id)
                    NSLog("isim Photos: saved %@ to the photo library", (rec.file as NSString).lastPathComponent)
                } else if let id = c.target {
                    if c.reverting { _PHStore.revert(id) }
                    if let out = c.contentEditingOutput {
                        // rendering ran in the app; storing touches files only
                        try _PHStore.applyEdit(id, out)
                        NSLog("isim Photos: saved an edit of %@", id)
                    }
                    _PHStore.update { recs in
                        if let i = recs.firstIndex(where: { $0.id == id }) {
                            recs[i].favorite = c.isFavorite
                            if let d = c.creationDate { recs[i].created = d.timeIntervalSince1970 }
                        }
                    }
                    changed.insert(id)
                }
            } else if let d = r as? _PHDeleteRequest { deleteIDs += d.ids }
        }
        // albums: created, edited and deleted in request order
        for case let a as PHAssetCollectionChangeRequest in reqs {
            let visible = Set(_PHAuth.visible().map(\.id))
            _PHStore.updateAlbums { albums in
                if a.deleting { albums.removeAll { a.target == $0.id }; return }
                var album: _PHAlbum
                if let t = a.target, let i = albums.firstIndex(where: { $0.id == t }) { album = albums[i] }
                else if a.target == nil { album = _PHAlbum(id: a.placeholder.localIdentifier, title: a.title) }
                else { return }
                album.title = a.title
                let before = Set(album.assets)
                album.assets = a.edits.reduce(album.assets) { ids, edit in edit(ids) }.filter { visible.contains($0) || before.contains($0) }
                var seen = Set<String>()
                album.assets = album.assets.filter { seen.insert($0).inserted }   // an asset appears once in an album
                if let i = albums.firstIndex(where: { $0.id == album.id }) { albums[i] = album } else { albums.append(album) }
            }
            changed.insert(a.target ?? a.placeholder.localIdentifier)
            if a.target == nil { NSLog("isim Photos: created the album %@", a.title) }
        }
        if !deleteIDs.isEmpty {
            // iOS asks the user before an app deletes photos
            let allowed: Bool = {
                if let sc = _Privacy.scripted("PHOTOS_DELETE") { return sc != "deny" }
                let sem = DispatchSemaphore(value: 0)
                let box = _Box(false)
                if Thread.isMainThread { NSLog("isim Photos: performChangesAndWait with a deletion on the main thread cannot show the confirmation; deleting"); return true }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        let n = deleteIDs.count
                        _Privacy.alert("Allow “\(_Privacy.appName)” to delete \(n == 1 ? "this photo" : "\(n) photos")?", nil, [("Don’t Allow", .cancel), ("Delete", .destructive)]) { i in
                            box.value = i == 1; sem.signal()
                        }
                    }
                }
                sem.wait()
                return box.value
            }()
            guard allowed else { throw PHPhotosError(.userCancelled) }
            let ids = Set(deleteIDs)
            _PHStore.update { recs in
                for r in recs where ids.contains(r.id) {
                    for f in [r.file, r.live, r.originalFile, r.adjustment] where !f.isEmpty {
                        try? FileManager.default.removeItem(atPath: (_PHStore.media as NSString).appendingPathComponent(f))
                    }
                }
                recs.removeAll { ids.contains($0.id) }
            }
            _PHStore.updateAlbums { albums in for i in albums.indices { albums[i].assets.removeAll { ids.contains($0) } } }
            changed.formUnion(ids)
        }
        notify(changed)
    }
}

// MARK: - Objects

@objc(PHObject) open class PHObject: NSObject, NSCopying, @unchecked Sendable {
    @objc public internal(set) var localIdentifier: String
    @objc init(id: String) { localIdentifier = id }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    @objc open override func isEqual(_ object: Any?) -> Bool { (object as? PHObject)?.localIdentifier == localIdentifier }
    @objc open override var hash: Int { localIdentifier.hashValue }
}
@objc(PHObjectPlaceholder) open class PHObjectPlaceholder: PHObject, @unchecked Sendable {}

@objc(PHAsset) open class PHAsset: PHObject, @unchecked Sendable {
    let rec: _PHRecord
    init(_ r: _PHRecord) { rec = r; super.init(id: r.id) }
    @objc open var mediaType: PHAssetMediaType { rec.isVideo ? .video : .image }
    open var mediaSubtypes: PHAssetMediaSubtype { rec.live.isEmpty ? [] : .photoLive }
    @objc(mediaSubtypes) var _objcMediaSubtypes: UInt { mediaSubtypes.rawValue }
    @objc open var sourceType: PHAssetSourceType { .typeUserLibrary }
    @objc open var pixelWidth: Int { rec.width }
    @objc open var pixelHeight: Int { rec.height }
    @objc open var creationDate: Date? { Date(timeIntervalSince1970: rec.created) }
    @objc open var modificationDate: Date? { rec.modified > 0 ? Date(timeIntervalSince1970: rec.modified) : creationDate }
    @objc open var location: AnyObject? { nil }
    @objc open var duration: TimeInterval { rec.duration }
    @objc open var isHidden: Bool { false }
    @objc open var isFavorite: Bool { rec.favorite }
    @objc open var burstIdentifier: String? { nil }
    @objc open var representsBurst: Bool { false }
    @objc(canPerformEditOperation:) open func canPerform(_ editOperation: Int) -> Bool { true }
    /// the keys fetch predicates use (NSPredicate reads them with key-value coding)
    @objc open override func value(forKey key: String) -> Any? {
        switch key {
        case "localIdentifier": return localIdentifier
        case "mediaType": return NSNumber(value: mediaType.rawValue)
        case "mediaSubtypes": return NSNumber(value: mediaSubtypes.rawValue)
        case "creationDate": return creationDate
        case "modificationDate": return modificationDate
        case "playbackStyle": return NSNumber(value: playbackStyle.rawValue)
        case "pixelWidth": return NSNumber(value: pixelWidth)
        case "pixelHeight": return NSNumber(value: pixelHeight)
        case "duration": return NSNumber(value: duration)
        case "favorite", "isFavorite": return NSNumber(value: isFavorite)
        case "hidden", "isHidden": return NSNumber(value: isHidden)
        case "burstIdentifier": return burstIdentifier
        default: return super.value(forKey: key)
        }
    }
    @objc open override var description: String { "<PHAsset: \(localIdentifier)> mediaType=\(mediaType.rawValue)/0, sourceType=1, (\(rec.width)x\(rec.height)), creationDate=\(creationDate!), favorite=\(isFavorite ? "YES" : "NO")" }

    static func fetch(_ recs: [_PHRecord], _ options: PHFetchOptions?) -> PHFetchResult<PHAsset> {
        var assets = recs.map(PHAsset.init)
        if let p = options?.predicate { assets = assets.filter { p.evaluate(with: $0) } }
        let sorts = options?.sortDescriptors ?? []
        assets.sort { $0.rec.created < $1.rec.created }
        for s in sorts.reversed() where s.key == "creationDate" || s.key == "modificationDate" {
            if !s.ascending { assets.reverse() }
        }
        if let lim = options?.fetchLimit, lim > 0, assets.count > lim { assets = Array(assets.prefix(lim)) }
        let opts = options
        return PHFetchResult(assets) { PHAsset.fetch(_PHAuth.visible(), opts) }
    }
    open class func fetchAssets(with options: PHFetchOptions?) -> PHFetchResult<PHAsset> { fetch(_PHAuth.visible(), options) }
    open class func fetchAssets(with mediaType: PHAssetMediaType, options: PHFetchOptions?) -> PHFetchResult<PHAsset> {
        let opts = options
        let r = fetch(_PHAuth.visible().filter { $0.isVideo == (mediaType == .video) && (mediaType == .image || mediaType == .video) }, options)
        return PHFetchResult(r.items) { PHAsset.fetchAssets(with: mediaType, options: opts) }
    }
    open class func fetchAssets(withLocalIdentifiers identifiers: [String], options: PHFetchOptions?) -> PHFetchResult<PHAsset> {
        let ids = Set(identifiers)
        let order = Dictionary(uniqueKeysWithValues: identifiers.enumerated().map { ($1, $0) })
        let r = fetch(_PHAuth.visible().filter { ids.contains($0.id) }, options)
        if options?.sortDescriptors == nil { return PHFetchResult(r.items.sorted { (order[$0.localIdentifier] ?? 0) < (order[$1.localIdentifier] ?? 0) }) { r.refetched().items } }
        return r
    }
    open class func fetchAssets(in assetCollection: PHAssetCollection, options: PHFetchOptions?) -> PHFetchResult<PHAsset> {
        var recs = _PHAuth.visible()
        if assetCollection.assetCollectionType == .album {
            // a user album keeps its own order unless the options sort it
            let id = assetCollection.localIdentifier, opts = options
            func albumAssets() -> [PHAsset] {
                let ids = _PHStore.albums().first { $0.id == id }?.assets ?? []
                let byID = Dictionary(uniqueKeysWithValues: _PHAuth.visible().map { ($0.id, $0) })
                let inAlbum = ids.compactMap { byID[$0] }
                if opts?.sortDescriptors?.isEmpty == false { return fetch(inAlbum, opts).items }
                var assets = inAlbum.map(PHAsset.init)
                if let p = opts?.predicate { assets = assets.filter { p.evaluate(with: $0) } }
                if let lim = opts?.fetchLimit, lim > 0, assets.count > lim { assets = Array(assets.prefix(lim)) }
                return assets
            }
            return PHFetchResult(albumAssets(), again: albumAssets)
        }
        if assetCollection.assetCollectionSubtype == .smartAlbumFavorites { recs = recs.filter(\.favorite) }
        else if assetCollection.assetCollectionSubtype == .smartAlbumVideos { recs = recs.filter(\.isVideo) }
        return fetch(recs, options)
    }
    open class func fetchKeyAssets(in assetCollection: PHAssetCollection, options: PHFetchOptions?) -> PHFetchResult<PHAsset>? {
        fetchAssets(in: assetCollection, options: options)
    }
}

@objc(PHCollection) open class PHCollection: PHObject, @unchecked Sendable {
    @objc open var localizedTitle: String? { nil }
    @objc open var canContainAssets: Bool { true }
    @objc open var canContainCollections: Bool { false }
    /// user albums can be renamed, deleted and edited; smart albums cannot
    @objc(canPerformEditOperation:) open func canPerform(_ anOperation: PHCollectionEditOperation) -> Bool { false }
    /// the user's albums (isim has no folders)
    open class func fetchTopLevelUserCollections(with options: PHFetchOptions?) -> PHFetchResult<PHCollection> {
        let r = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        return PHFetchResult(r.items) { r.refetched().items }
    }
}
@objc(PHAssetCollection) open class PHAssetCollection: PHCollection, @unchecked Sendable {
    @objc public let assetCollectionType: PHAssetCollectionType
    @objc public let assetCollectionSubtype: PHAssetCollectionSubtype
    @objc let title: String
    @objc let created: Date?
    @objc init(_ type: PHAssetCollectionType, _ sub: PHAssetCollectionSubtype, _ title: String) {
        assetCollectionType = type; assetCollectionSubtype = sub; self.title = title; created = nil
        super.init(id: "isim-collection-\(sub.rawValue)/L0/040")
    }
    /// a user album
    init(_ album: _PHAlbum) {
        assetCollectionType = .album; assetCollectionSubtype = .albumRegular; title = album.title
        created = Date(timeIntervalSince1970: album.created)
        super.init(id: album.id)
    }
    @objc open override var localizedTitle: String? { title }
    @objc open var estimatedAssetCount: Int { PHAsset.fetchAssets(in: self, options: nil).count }
    @objc open var startDate: Date? { nil }
    @objc open var endDate: Date? { nil }
    @objc open override func canPerform(_ anOperation: PHCollectionEditOperation) -> Bool {
        assetCollectionType == .album && anOperation != .createContent
    }
    @objc open override func value(forKey key: String) -> Any? {
        switch key {
        case "localIdentifier": return localIdentifier
        case "title", "localizedTitle": return title
        case "estimatedAssetCount": return NSNumber(value: estimatedAssetCount)
        case "startDate": return startDate
        case "endDate": return endDate
        default: return super.value(forKey: key)
        }
    }
    @objc static func userAlbums(_ options: PHFetchOptions?) -> [PHAssetCollection] {
        var r = _PHStore.albums().map(PHAssetCollection.init)
        if let p = options?.predicate { r = r.filter { p.evaluate(with: $0) } }
        for s in (options?.sortDescriptors ?? []).reversed() where s.key == "title" || s.key == "localizedTitle" || s.key == "startDate" {
            r.sort { s.key == "startDate" ? ($0.created ?? .distantPast) < ($1.created ?? .distantPast) : $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if !s.ascending { r.reverse() }
        }
        if let lim = options?.fetchLimit, lim > 0, r.count > lim { r = Array(r.prefix(lim)) }
        return r
    }
    @objc static let smart: [PHAssetCollection] = [PHAssetCollection(.smartAlbum, .smartAlbumUserLibrary, "Recents"),
                                             PHAssetCollection(.smartAlbum, .smartAlbumFavorites, "Favorites"),
                                             PHAssetCollection(.smartAlbum, .smartAlbumVideos, "Videos")]
    open class func fetchAssetCollections(with type: PHAssetCollectionType, subtype: PHAssetCollectionSubtype, options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection> {
        if type == .album {
            let albums = { (subtype == .any || subtype == .albumRegular) ? userAlbums(options) : [] }
            return PHFetchResult(albums(), again: albums)
        }
        let r = smart.filter { (type == .smartAlbum) && (subtype == .any || subtype == .albumRegular || $0.assetCollectionSubtype == subtype) }
        return PHFetchResult(type == .smartAlbum ? r : []) { type == .smartAlbum ? r : [] }
    }
    open class func fetchAssetCollections(withLocalIdentifiers identifiers: [String], options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection> {
        let find = { (smart + userAlbums(nil)).filter { identifiers.contains($0.localIdentifier) } }
        return PHFetchResult(find(), again: find)
    }
    /// the user albums (and, for .smartAlbum, the smart albums) holding the asset
    open class func fetchAssetCollectionsContaining(_ asset: PHAsset, with type: PHAssetCollectionType, options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection> {
        let id = asset.localIdentifier
        let find: () -> [PHAssetCollection] = {
            if type == .album { return userAlbums(options).filter { a in _PHStore.albums().first { $0.id == a.localIdentifier }?.assets.contains(id) == true } }
            if type == .smartAlbum { return smart.filter { PHAsset.fetchAssets(in: $0, options: nil).items.contains { $0.localIdentifier == id } } }
            return []
        }
        return PHFetchResult(find(), again: find)
    }
}

@objc(PHFetchOptions) open class PHFetchOptions: NSObject, NSCopying, @unchecked Sendable {
    @objc open var predicate: NSPredicate?
    @objc open var sortDescriptors: [NSSortDescriptor]?
    @objc open var includeHiddenAssets = false
    @objc open var includeAllBurstAssets = false
    @objc open var includeAssetSourceTypes: PHAssetSourceType = .typeUserLibrary
    @objc open var fetchLimit = 0
    @objc open var wantsIncrementalChangeDetails = true
    @objc public override init() { super.init() }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any {
        let o = PHFetchOptions(); o.predicate = predicate; o.sortDescriptors = sortDescriptors; o.fetchLimit = fetchLimit; return o
    }
}

open class PHFetchResult<ObjectType: AnyObject>: NSObject, NSCopying, @unchecked Sendable {
    let items: [ObjectType]
    let again: () -> [ObjectType]
    init(_ items: [ObjectType], again: @escaping () -> [ObjectType]) { self.items = items; self.again = again }
    convenience init(_ items: [ObjectType], _ refetch: @escaping () -> PHFetchResult<ObjectType>) { self.init(items, again: { refetch().items }) }
    func refetched() -> PHFetchResult<ObjectType> { PHFetchResult(again(), again: again) }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open var count: Int { items.count }
    open func object(at index: Int) -> ObjectType { items[index] }
    open subscript(index: Int) -> ObjectType { items[index] }
    open var firstObject: ObjectType? { items.first }
    open var lastObject: ObjectType? { items.last }
    open func contains(_ anObject: ObjectType) -> Bool { items.contains { $0 === anObject || ($0 as? NSObject)?.isEqual(anObject) == true } }
    open func index(of anObject: ObjectType) -> Int { items.firstIndex { $0 === anObject || ($0 as? NSObject)?.isEqual(anObject) == true } ?? NSNotFound }
    open func objects(at indexes: IndexSet) -> [ObjectType] { indexes.map { items[$0] } }
    open func countOfAssets(with mediaType: PHAssetMediaType) -> Int { items.filter { ($0 as? PHAsset)?.mediaType == mediaType }.count }
    open func enumerateObjects(_ block: (ObjectType, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop = ObjCBool(false)
        for (i, o) in items.enumerated() { block(o, i, &stop); if stop.boolValue { break } }
    }
    open func enumerateObjects(options opts: NSEnumerationOptions = [], using block: (ObjectType, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateObjects(block)
    }
}

// MARK: - Change requests

enum _PHChanges {
    nonisolated(unsafe) static var current: [NSObject]?
    static func begin() { current = [] }
    static func end() -> [NSObject] { defer { current = nil }; return current ?? [] }
    static func add(_ r: NSObject) {
        if current == nil { NSLog("isim Photos: change requests can only be made inside -[PHPhotoLibrary performChanges:] (iOS raises an exception)") }
        current?.append(r)
    }
}
final class _PHDeleteRequest: NSObject { let ids: [String]; init(_ ids: [String]) { self.ids = ids } }

@objc(PHAssetChangeRequest) open class PHAssetChangeRequest: NSObject, @unchecked Sendable {
    @objc var creating = false
    @objc var image: UIImage?, fileURL: URL?, resourceData: Data?
    /// a movie to add (creationRequestForAssetFromVideo, or a .video resource)
    @objc var videoFile: URL?
    /// a Live Photo's movie (a .pairedVideo resource)
    @objc var pairedVideo: URL?
    @objc var reverting = false
    @objc var target: String?
    @objc let placeholder = PHObjectPlaceholder(id: "\(UUID().uuidString)/L0/001")   // assigned up front, like iOS
    @objc open var creationDate: Date?
    @nonobjc open var isFavorite = false
    @nonobjc open var isHidden = false
    @objc open var location: AnyObject?
    @objc open var placeholderForCreatedAsset: PHObjectPlaceholder? { creating ? placeholder : nil }
    /// an edit to store (Editing.swift)
    @objc open var contentEditingOutput: PHContentEditingOutput?

    @objc public required override init() { super.init() }
    @objc public convenience init(for asset: PHAsset) {
        self.init()
        target = asset.localIdentifier; isFavorite = asset.isFavorite
        _PHChanges.add(self)
    }
    @objc(creationRequestForAssetFromImage:) open class func creationRequestForAsset(from image: UIImage) -> Self {
        let r = Self.init(); r.creating = true; r.image = image; _PHChanges.add(r); return r
    }
    @objc open class func creationRequestForAssetFromImage(atFileURL fileURL: URL) -> Self? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let r = Self.init(); r.creating = true; r.fileURL = fileURL; _PHChanges.add(r); return r
    }
    @objc open class func creationRequestForAssetFromVideo(atFileURL fileURL: URL) -> Self? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let r = Self.init(); r.creating = true; r.videoFile = fileURL; _PHChanges.add(r); return r
    }
    @objc open class func deleteAssets(_ assets: Any) {
        var ids: [String] = []
        if let a = assets as? [PHAsset] { ids = a.map(\.localIdentifier) }
        else if let r = assets as? PHFetchResult<PHAsset> { ids = r.items.map(\.localIdentifier) }
        else { ids = _PHObjC.objects(assets).compactMap { ($0 as? PHAsset)?.localIdentifier } }   // [Any], Objective-C's PHFetchResult
        _PHChanges.add(_PHDeleteRequest(ids))
    }
    /// drops the asset's edit, back to the original
    @objc open func revertAssetContentToOriginal() { reverting = true }

    /// data, extension and pixel size of the asset to create
    func payload() -> (Data, String, Int, Int)? {
        if let image, let d = image.pngData() {
            return (d, "PNG", Int(image.size.width * image.scale), Int(image.size.height * image.scale))
        }
        if let d = resourceData ?? fileURL.flatMap({ FileManager.default.contents(atPath: $0.path) }) {
            let ext = fileURL?.pathExtension.uppercased() ?? (d.starts(with: [0x89, 0x50]) ? "PNG" : "JPG")
            let img = UIImage(data: d)
            return (d, ext.isEmpty ? "JPG" : ext, Int((img?.size.width ?? 0) * (img?.scale ?? 1)), Int((img?.size.height ?? 0) * (img?.scale ?? 1)))
        }
        return nil
    }
}

@objc(PHAssetResourceCreationOptions) open class PHAssetResourceCreationOptions: NSObject, @unchecked Sendable {
    @objc open var originalFilename: String?
    @objc open var uniformTypeIdentifier: String?
    @objc open var shouldMoveFile = false
    @objc public override init() { super.init() }
}
@objc(PHAssetCreationRequest) open class PHAssetCreationRequest: PHAssetChangeRequest, @unchecked Sendable {
    @objc(creationRequestForAsset) open class func forAsset() -> PHAssetCreationRequest { let r = PHAssetCreationRequest(); r.creating = true; _PHChanges.add(r); return r }
    /// one photo, one video, or a Live Photo (a photo and its paired video)
    @objc open class func supportsAssetResourceTypes(_ types: [NSNumber]) -> Bool {
        let t = Set(types.map { Int($0.intValue) })
        guard t.count == types.count else { return false }
        let photo = PHAssetResourceType.photo.rawValue, video = PHAssetResourceType.video.rawValue, paired = PHAssetResourceType.pairedVideo.rawValue
        return t == [photo] || t == [video] || t == [photo, paired]
    }
    @objc(addResourceWithType:data:options:) open func addResource(with type: PHAssetResourceType, data: Data, options: PHAssetResourceCreationOptions?) {
        if type == .photo { resourceData = data }
        else if type == .video || type == .pairedVideo {
            let ext = options?.originalFilename.map { ($0 as NSString).pathExtension }.flatMap { $0.isEmpty ? nil : $0 } ?? "mov"
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("isim-photos-\(UUID().uuidString).\(ext)")
            if (try? data.write(to: url)) != nil { if type == .video { videoFile = url } else { pairedVideo = url } }
        }
    }
    @objc(addResourceWithType:fileURL:options:) open func addResource(with type: PHAssetResourceType, fileURL: URL, options: PHAssetResourceCreationOptions?) {
        if type == .photo { self.fileURL = fileURL } else if type == .video { videoFile = fileURL } else if type == .pairedVideo { pairedVideo = fileURL }
    }
}

// MARK: - Albums

@objc(PHAssetCollectionChangeRequest) open class PHAssetCollectionChangeRequest: NSObject, @unchecked Sendable {
    @objc var target: String?
    @objc var deleting = false
    /// edits of the album's asset identifiers, applied in order
    var edits: [([String]) -> [String]] = []
    @objc let placeholder = PHObjectPlaceholder(id: "\(UUID().uuidString)/L0/040")
    @objc open var title: String
    @objc open var placeholderForCreatedAssetCollection: PHObjectPlaceholder { placeholder }

    @objc init(title: String, target: String?) { self.title = title; self.target = target; super.init() }
    @objc open class func creationRequestForAssetCollection(withTitle title: String) -> Self {
        let r = PHAssetCollectionChangeRequest(title: title, target: nil); _PHChanges.add(r); return r as! Self
    }
    /// nil for a smart album (it cannot be edited)
    @objc public convenience init?(for assetCollection: PHAssetCollection) {
        guard assetCollection.assetCollectionType == .album else { return nil }
        self.init(title: assetCollection.title, target: assetCollection.localIdentifier)
        _PHChanges.add(self)
    }
    /// assets: the album's contents as the app fetched them, so index-based edits refer to them
    public convenience init?(for assetCollection: PHAssetCollection, assets: PHFetchResult<PHAsset>) {
        self.init(for: assetCollection)
        let ids = assets.items.map(\.localIdentifier)
        edits.append { _ in ids }
    }
    @objc open class func deleteAssetCollections(_ assetCollections: Any) {
        for id in Self._ids(assetCollections) {
            let r = PHAssetCollectionChangeRequest(title: "", target: id); r.deleting = true; _PHChanges.add(r)
        }
    }
    @objc static func _ids(_ objects: Any) -> [String] {
        if let a = objects as? [PHObject] { return a.map(\.localIdentifier) }
        if let r = objects as? PHFetchResult<PHAssetCollection> { return r.items.map(\.localIdentifier) }
        if let r = objects as? PHFetchResult<PHAsset> { return r.items.map(\.localIdentifier) }
        if let a = objects as? [Any] { return a.compactMap { ($0 as? PHObject)?.localIdentifier } }
        if let a = objects as? NSArray { return (0 ..< a.count).compactMap { (a.object(at: $0) as? PHObject)?.localIdentifier } }
        return _PHObjC.objects(objects).compactMap { ($0 as? PHObject)?.localIdentifier }   // Objective-C's PHFetchResult
    }
    @objc open func addAssets(_ assets: Any) {
        let ids = Self._ids(assets)
        edits.append { $0 + ids }
    }
    @objc(insertAssets:atIndexes:) open func insertAssets(_ assets: Any, at indexes: IndexSet) {
        let ids = Self._ids(assets)
        edits.append { cur in
            var out = cur
            for (id, i) in zip(ids, indexes) { out.insert(id, at: min(i, out.count)) }
            return out
        }
    }
    @objc open func removeAssets(_ assets: Any) {
        let ids = Set(Self._ids(assets))
        edits.append { $0.filter { !ids.contains($0) } }
    }
    @objc(removeAssetsAtIndexes:) open func removeAssets(at indexes: IndexSet) {
        edits.append { cur in cur.enumerated().filter { !indexes.contains($0.offset) }.map(\.element) }
    }
    @objc(replaceAssetsAtIndexes:withAssets:) open func replaceAssets(at indexes: IndexSet, withAssets assets: Any) {
        let ids = Self._ids(assets)
        edits.append { cur in
            var out = cur
            for (i, id) in zip(indexes, ids) where i < out.count { out[i] = id }
            return out
        }
    }
    @objc(moveAssetsAtIndexes:toIndex:) open func moveAssets(at fromIndexes: IndexSet, to toIndex: Int) {
        edits.append { cur in
            let moving = fromIndexes.filter { $0 < cur.count }.map { cur[$0] }
            var rest = cur.enumerated().filter { !fromIndexes.contains($0.offset) }.map(\.element)
            rest.insert(contentsOf: moving, at: min(toIndex, rest.count))
            return rest
        }
    }
}
