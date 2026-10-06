// isim Photos (self-authored, iOS API names): the device photo library ($ISIM_DATA/Media, shared with UIKit's
// UIImagePickerController and UIImageWriteToSavedPhotosAlbum; seeded with six sample pictures on first use), the
// photo library permission (iOS 17/18 alert: Limit Access… / Allow Full Access / Don't Allow, and the add-only
// alert), PHAsset fetching, PHImageManager image requests and PHAssetChangeRequest saving.
// Images only (adapted): no videos, Live Photos, iCloud, albums beyond the smart albums, or edits.
// Automation: ISIM_PHOTOS_PERMISSION=allow|limited|deny answers without the alert (limited selects nothing).
import UIKit

@_silgen_name("_isim_photos_seed") func _isimPhotosSeed()

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
@objc public enum PHAssetResourceType: Int, Sendable { case photo = 1, video, audio, alternatePhoto, fullSizePhoto, fullSizeVideo, adjustmentData }
@objc public enum PHAssetCollectionType: Int, Sendable { case album = 1, smartAlbum = 2, moment = 3 }
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
    init(_ d: [String: Any]) {
        id = d["id"] as? String ?? ""; file = d["file"] as? String ?? ""
        created = (d["created"] as? NSNumber)?.doubleValue ?? 0
        width = (d["width"] as? NSNumber)?.integerValue ?? 0; height = (d["height"] as? NSNumber)?.integerValue ?? 0
        favorite = (d["favorite"] as? NSNumber)?.boolValue ?? false; app = d["app"] as? String ?? ""
    }
    var dict: [String: Any] {
        ["id": id, "file": file, "created": NSNumber(value: created), "width": NSNumber(value: width), "height": NSNumber(value: height),
         "favorite": NSNumber(value: favorite), "app": app]
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

open class PHChange: NSObject, @unchecked Sendable {
    let changedIDs: Set<String>
    init(_ ids: Set<String>) { changedIDs = ids }
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

open class PHPhotoLibrary: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static let sharedLibrary = PHPhotoLibrary()
    var observers: [() -> PHPhotoLibraryChangeObserver?] = []
    open class func shared() -> PHPhotoLibrary { sharedLibrary }
    open var unavailabilityReason: Error? { nil }

    open class func authorizationStatus() -> PHAuthorizationStatus {
        let s = _PHAuth.status
        return s == .limited ? .authorized : s                  // the old API reports limited as authorized, like iOS
    }
    open class func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        accessLevel == .addOnly ? _PHAuth.addStatus : _PHAuth.status
    }
    open class func requestAuthorization(_ handler: @escaping (PHAuthorizationStatus) -> Void) {
        requestAuthorization(for: .readWrite) { s in handler(s == .limited ? .authorized : s) }
    }
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
    open class func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        await withCheckedContinuation { k in requestAuthorization(for: accessLevel) { k.resume(returning: $0) } }
    }

    open func register(_ observer: PHPhotoLibraryChangeObserver) { observers.append { [weak observer] in observer } }
    open func unregisterChangeObserver(_ observer: PHPhotoLibraryChangeObserver) { observers.removeAll { $0() === observer || $0() == nil } }
    open func register(_ observer: PHPhotoLibraryAvailabilityObserver) {}
    open func unregisterAvailabilityObserver(_ observer: PHPhotoLibraryAvailabilityObserver) {}

    /// iOS 14+: lets a limited-access app change its selection
    @MainActor open func presentLimitedLibraryPicker(from controller: UIViewController) {
        presentLimitedLibraryPicker(from: controller) { _ in }
    }
    @MainActor open func presentLimitedLibraryPicker(from controller: UIViewController, completionHandler: @escaping ([String]) -> Void) {
        guard _PHAuth.status == .limited else { completionHandler([]); return }
        let before = _PHAuth.limited
        _PHSelection.present(selected: before) { ids in
            _PHAuth.limited = ids
            self.notify(ids.symmetricDifference(before))
            completionHandler(Array(ids.subtracting(before)))
        }
    }

    func notify(_ ids: Set<String>) {
        let change = PHChange(ids)
        for o in observers { if let ob = o() { DispatchQueue.global().async { ob.photoLibraryDidChange(change) } } }
    }

    // MARK: changes
    open func performChanges(_ changeBlock: @escaping () -> Void, completionHandler: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global().async {
            do { try self.performChangesAndWait(changeBlock); completionHandler?(true, nil) }
            catch { completionHandler?(false, error) }
        }
    }
    open func performChanges(_ changeBlock: @escaping @Sendable () -> Void) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            performChanges(changeBlock) { _, e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func performChangesAndWait(_ changeBlock: () -> Void) throws {
        _PHChanges.begin()
        changeBlock()
        let reqs = _PHChanges.end()
        if reqs.isEmpty { return }
        let needsRead = reqs.contains { !($0 is PHAssetCreationRequest || ($0 is PHAssetChangeRequest && ($0 as! PHAssetChangeRequest).creating)) }
        let ok = needsRead ? (_PHAuth.status == .authorized || _PHAuth.status == .limited) : _PHAuth.addStatus == .authorized
        guard ok else { throw PHPhotosError(.accessUserDenied) }
        var changed = Set<String>()
        var deleteIDs: [String] = []
        for r in reqs {
            if let c = r as? PHAssetChangeRequest {
                if c.creating {
                    guard let (data, ext, w, h) = c.payload(), let rec = _PHStore.add(data, ext: ext, width: w, height: h, created: c.creationDate ?? Date(), id: c.placeholder.localIdentifier) else {
                        throw PHPhotosError(.invalidResource)
                    }
                    c.placeholder.localIdentifier = rec.id
                    if c.isFavorite { _PHStore.update { recs in if let i = recs.firstIndex(where: { $0.id == rec.id }) { recs[i].favorite = true } } }
                    if _PHAuth.status == .limited { _PHAuth.limited = _PHAuth.limited.union([rec.id]) }
                    changed.insert(rec.id)
                    NSLog("isim Photos: saved %@ to the photo library", (rec.file as NSString).lastPathComponent)
                } else if let id = c.target {
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
                for r in recs where ids.contains(r.id) { try? FileManager.default.removeItem(atPath: _PHStore.path(r)) }
                recs.removeAll { ids.contains($0.id) }
            }
            changed.formUnion(ids)
        }
        notify(changed)
    }
}

// MARK: - Objects

open class PHObject: NSObject, NSCopying, @unchecked Sendable {
    public internal(set) var localIdentifier: String
    init(id: String) { localIdentifier = id }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    open override func isEqual(_ object: Any?) -> Bool { (object as? PHObject)?.localIdentifier == localIdentifier }
    open override var hash: Int { localIdentifier.hashValue }
}
open class PHObjectPlaceholder: PHObject, @unchecked Sendable {}

open class PHAsset: PHObject, @unchecked Sendable {
    let rec: _PHRecord
    init(_ r: _PHRecord) { rec = r; super.init(id: r.id) }
    open var mediaType: PHAssetMediaType { .image }
    open var mediaSubtypes: PHAssetMediaSubtype { [] }
    open var sourceType: PHAssetSourceType { .typeUserLibrary }
    open var pixelWidth: Int { rec.width }
    open var pixelHeight: Int { rec.height }
    open var creationDate: Date? { Date(timeIntervalSince1970: rec.created) }
    open var modificationDate: Date? { creationDate }
    open var location: AnyObject? { nil }
    open var duration: TimeInterval { 0 }
    open var isHidden: Bool { false }
    open var isFavorite: Bool { rec.favorite }
    open var burstIdentifier: String? { nil }
    open var representsBurst: Bool { false }
    open func canPerform(_ editOperation: Int) -> Bool { true }
    open override var description: String { "<PHAsset: \(localIdentifier)> mediaType=1/0, sourceType=1, (\(rec.width)x\(rec.height)), creationDate=\(creationDate!), favorite=\(isFavorite ? "YES" : "NO")" }

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
        mediaType == .image ? fetch(_PHAuth.visible(), options) : PHFetchResult([]) { [] }
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
        if assetCollection.assetCollectionSubtype == .smartAlbumFavorites { recs = recs.filter(\.favorite) }
        else if assetCollection.assetCollectionSubtype == .smartAlbumVideos { recs = [] }
        return fetch(recs, options)
    }
    open class func fetchKeyAssets(in assetCollection: PHAssetCollection, options: PHFetchOptions?) -> PHFetchResult<PHAsset>? {
        fetchAssets(in: assetCollection, options: options)
    }
}

open class PHCollection: PHObject, @unchecked Sendable {
    open var localizedTitle: String? { nil }
    open var canContainAssets: Bool { true }
    open var canContainCollections: Bool { false }
}
open class PHAssetCollection: PHCollection, @unchecked Sendable {
    public let assetCollectionType: PHAssetCollectionType
    public let assetCollectionSubtype: PHAssetCollectionSubtype
    let title: String
    init(_ type: PHAssetCollectionType, _ sub: PHAssetCollectionSubtype, _ title: String) {
        assetCollectionType = type; assetCollectionSubtype = sub; self.title = title
        super.init(id: "isim-collection-\(sub.rawValue)/L0/040")
    }
    open override var localizedTitle: String? { title }
    open var estimatedAssetCount: Int { PHAsset.fetchAssets(in: self, options: nil).count }
    open var startDate: Date? { nil }
    open var endDate: Date? { nil }
    static let smart: [PHAssetCollection] = [PHAssetCollection(.smartAlbum, .smartAlbumUserLibrary, "Recents"),
                                             PHAssetCollection(.smartAlbum, .smartAlbumFavorites, "Favorites"),
                                             PHAssetCollection(.smartAlbum, .smartAlbumVideos, "Videos")]
    open class func fetchAssetCollections(with type: PHAssetCollectionType, subtype: PHAssetCollectionSubtype, options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection> {
        let r = smart.filter { (type == .smartAlbum) && (subtype == .any || subtype == .albumRegular || $0.assetCollectionSubtype == subtype) }
        return PHFetchResult(type == .smartAlbum ? r : []) { type == .smartAlbum ? r : [] }
    }
    open class func fetchAssetCollections(withLocalIdentifiers identifiers: [String], options: PHFetchOptions?) -> PHFetchResult<PHAssetCollection> {
        let r = smart.filter { identifiers.contains($0.localIdentifier) }
        return PHFetchResult(r) { r }
    }
}

open class PHFetchOptions: NSObject, NSCopying, @unchecked Sendable {
    open var predicate: NSPredicate?
    open var sortDescriptors: [NSSortDescriptor]?
    open var includeHiddenAssets = false
    open var includeAllBurstAssets = false
    open var includeAssetSourceTypes: PHAssetSourceType = .typeUserLibrary
    open var fetchLimit = 0
    open var wantsIncrementalChangeDetails = true
    public override init() { super.init() }
    public func copy(with zone: OpaquePointer? = nil) -> Any {
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
    open func countOfAssets(with mediaType: PHAssetMediaType) -> Int { mediaType == .image ? items.count : 0 }
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

open class PHAssetChangeRequest: NSObject, @unchecked Sendable {
    var creating = false
    var image: UIImage?, fileURL: URL?, resourceData: Data?
    var target: String?
    let placeholder = PHObjectPlaceholder(id: "\(UUID().uuidString)/L0/001")   // assigned up front, like iOS
    open var creationDate: Date?
    open var isFavorite = false
    open var isHidden = false
    open var location: AnyObject?
    open var placeholderForCreatedAsset: PHObjectPlaceholder? { creating ? placeholder : nil }

    public required override init() { super.init() }
    public convenience init(for asset: PHAsset) {
        self.init()
        target = asset.localIdentifier; isFavorite = asset.isFavorite
        _PHChanges.add(self)
    }
    open class func creationRequestForAsset(from image: UIImage) -> Self {
        let r = Self.init(); r.creating = true; r.image = image; _PHChanges.add(r); return r
    }
    open class func creationRequestForAssetFromImage(atFileURL fileURL: URL) -> Self? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let r = Self.init(); r.creating = true; r.fileURL = fileURL; _PHChanges.add(r); return r
    }
    open class func creationRequestForAssetFromVideo(atFileURL fileURL: URL) -> Self? {
        NSLog("isim Photos: saving videos is not supported (images only)")
        return nil
    }
    open class func deleteAssets(_ assets: Any) {
        var ids: [String] = []
        if let a = assets as? [PHAsset] { ids = a.map(\.localIdentifier) }
        else if let r = assets as? PHFetchResult<PHAsset> { ids = r.items.map(\.localIdentifier) }
        else if let a = assets as? [Any] { ids = a.compactMap { ($0 as? PHAsset)?.localIdentifier } }
        _PHChanges.add(_PHDeleteRequest(ids))
    }
    open func revertAssetContentToOriginal() {}

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

open class PHAssetResourceCreationOptions: NSObject, @unchecked Sendable {
    open var originalFilename: String?
    open var uniformTypeIdentifier: String?
    open var shouldMoveFile = false
    public override init() { super.init() }
}
open class PHAssetCreationRequest: PHAssetChangeRequest, @unchecked Sendable {
    open class func forAsset() -> PHAssetCreationRequest { let r = PHAssetCreationRequest(); r.creating = true; _PHChanges.add(r); return r }
    open class func supportsAssetResourceTypes(_ types: [NSNumber]) -> Bool { types.allSatisfy { $0.integerValue == PHAssetResourceType.photo.rawValue } }
    open func addResource(with type: PHAssetResourceType, data: Data, options: PHAssetResourceCreationOptions?) { if type == .photo { resourceData = data } }
    open func addResource(with type: PHAssetResourceType, fileURL: URL, options: PHAssetResourceCreationOptions?) { if type == .photo { self.fileURL = fileURL } }
}
