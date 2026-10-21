// isim Photos: the Objective-C interface (sdk-src/Frameworks/Photos, issue #545). The classes are @objc(PH…) and
// @objcMembers, so what Objective-C can represent is exported under Apple's names; the members below are internal
// Objective-C entry points, under Apple's selectors, for what uses Swift-only types. PHFetchResult and the change
// details are Swift generics, which Objective-C cannot see: Objective-C has its own classes of those names
// (frameworks/Photos/Photos.m) over the arrays the fetches below return.
import UIKit

/// Apple's PHPhotoLibraryChangeObserver as Objective-C sees it (Swift has its own, non-@objc protocol)
@objc(PHPhotoLibraryChangeObserver) protocol _PHObjCChangeObserver: NSObjectProtocol {
    @objc(photoLibraryDidChange:) func photoLibraryDidChange(_ changeInstance: PHChange)
}
/// a Swift observer standing for an Objective-C one (held weakly, like iOS)
final class _PHObjCObserverBox: PHPhotoLibraryChangeObserver {
    weak var target: _PHObjCChangeObserver?
    init(_ t: _PHObjCChangeObserver) { target = t }
    func photoLibraryDidChange(_ changeInstance: PHChange) { target?.photoLibraryDidChange(changeInstance) }
}
enum _PHObjC {
    nonisolated(unsafe) static var boxes: [ObjectIdentifier: _PHObjCObserverBox] = [:]
    static let lock = NSLock()
    /// the objects of a fetch result, an array or any collection Objective-C passes (`id<NSFastEnumeration>`)
    static func objects(_ any: Any) -> [Any] {
        if let a = any as? [Any] { return a }
        if let o = any as? NSObject, o.responds(to: NSSelectorFromString("_isim_allObjects")), let a = o.value(forKey: "_isim_allObjects") as? [Any] { return a }
        if let s = any as? NSSet { return s.allObjects }
        if let s = any as? NSOrderedSet { return s.array }
        return []
    }
}

extension PHPhotoLibrary {
    @objc(registerChangeObserver:) func _objcRegister(_ observer: _PHObjCChangeObserver) {
        let box = _PHObjCObserverBox(observer)
        _PHObjC.lock.lock(); _PHObjC.boxes[ObjectIdentifier(observer)] = box; _PHObjC.lock.unlock()
        register(box)
    }
    @objc(unregisterChangeObserver:) func _objcUnregister(_ observer: _PHObjCChangeObserver) {
        _PHObjC.lock.lock(); let box = _PHObjC.boxes.removeValue(forKey: ObjectIdentifier(observer)); _PHObjC.lock.unlock()
        if let box { unregisterChangeObserver(box) }
    }
    @objc(registerAvailabilityObserver:) func _objcRegisterAvailability(_ observer: AnyObject) {}
    @objc(unregisterAvailabilityObserver:) func _objcUnregisterAvailability(_ observer: AnyObject) {}
}

extension PHChange {
    /// the identifiers of the changed objects, for -changeDetailsForObject:
    @objc(_isim_changedIdentifiers) var _objcChangedIdentifiers: [String] { Array(changedIDs) }
}

// MARK: fetches (Photos.m wraps the arrays in Objective-C PHFetchResults, refetched the same way)

extension PHAsset {
    @objc(_isim_fetchAssetsWithOptions:) class func _objcFetch(options: PHFetchOptions?) -> [PHAsset] { fetchAssets(with: options).items }
    @objc(_isim_fetchAssetsWithMediaType:options:) class func _objcFetch(mediaType: PHAssetMediaType, options: PHFetchOptions?) -> [PHAsset] {
        fetchAssets(with: mediaType, options: options).items
    }
    @objc(_isim_fetchAssetsWithLocalIdentifiers:options:) class func _objcFetch(identifiers: [String], options: PHFetchOptions?) -> [PHAsset] {
        fetchAssets(withLocalIdentifiers: identifiers, options: options).items
    }
    @objc(_isim_fetchAssetsInAssetCollection:options:) class func _objcFetch(in collection: PHAssetCollection, options: PHFetchOptions?) -> [PHAsset] {
        fetchAssets(in: collection, options: options).items
    }
}
extension PHCollection {
    @objc(_isim_fetchTopLevelUserCollectionsWithOptions:) class func _objcFetchTopLevel(options: PHFetchOptions?) -> [PHCollection] {
        fetchTopLevelUserCollections(with: options).items
    }
}
extension PHAssetCollection {
    @objc(_isim_fetchAssetCollectionsWithType:subtype:options:)
    class func _objcFetch(type: PHAssetCollectionType, subtype: PHAssetCollectionSubtype, options: PHFetchOptions?) -> [PHAssetCollection] {
        fetchAssetCollections(with: type, subtype: subtype, options: options).items
    }
    @objc(_isim_fetchAssetCollectionsWithLocalIdentifiers:options:) class func _objcFetch(identifiers: [String], options: PHFetchOptions?) -> [PHAssetCollection] {
        fetchAssetCollections(withLocalIdentifiers: identifiers, options: options).items
    }
    @objc(_isim_fetchAssetCollectionsContainingAsset:withType:options:)
    class func _objcFetch(containing asset: PHAsset, type: PHAssetCollectionType, options: PHFetchOptions?) -> [PHAssetCollection] {
        fetchAssetCollectionsContaining(asset, with: type, options: options).items
    }
}

// MARK: change requests

extension PHAssetChangeRequest {
    @objc(changeRequestForAsset:) class func _objcChangeRequest(for asset: PHAsset) -> PHAssetChangeRequest { PHAssetChangeRequest(for: asset) }
    @objc(isFavorite) var _objcFavorite: Bool {
        get { isFavorite }
        @objc(setFavorite:) set { isFavorite = newValue }
    }
    @objc(isHidden) var _objcHidden: Bool {
        get { isHidden }
        @objc(setHidden:) set { isHidden = newValue }
    }
}
extension PHAssetCollectionChangeRequest {
    @objc(changeRequestForAssetCollection:) class func _objcChangeRequest(for collection: PHAssetCollection) -> PHAssetCollectionChangeRequest? {
        PHAssetCollectionChangeRequest(for: collection)
    }
    /// assets: an Objective-C PHFetchResult (its objects)
    @objc(changeRequestForAssetCollection:assets:) class func _objcChangeRequest(for collection: PHAssetCollection, assets: AnyObject) -> PHAssetCollectionChangeRequest? {
        guard let r = PHAssetCollectionChangeRequest(for: collection) else { return nil }
        let ids = _PHObjC.objects(assets).compactMap { ($0 as? PHObject)?.localIdentifier }
        r.edits.append { _ in ids }
        return r
    }
}

// MARK: requests with Swift-only types

extension PHImageRequestOptions {
    @objc(isNetworkAccessAllowed) var _objcNetworkAccessAllowed: Bool {
        get { isNetworkAccessAllowed }
        @objc(setNetworkAccessAllowed:) set { isNetworkAccessAllowed = newValue }
    }
    @objc(isSynchronous) var _objcSynchronous: Bool {
        get { isSynchronous }
        @objc(setSynchronous:) set { isSynchronous = newValue }
    }
}
extension PHVideoRequestOptions {
    @objc(isNetworkAccessAllowed) var _objcNetworkAccessAllowed: Bool {
        get { isNetworkAccessAllowed }
        @objc(setNetworkAccessAllowed:) set { isNetworkAccessAllowed = newValue }
    }
}
extension PHAssetResourceRequestOptions {
    @objc(isNetworkAccessAllowed) var _objcNetworkAccessAllowed: Bool {
        get { isNetworkAccessAllowed }
        @objc(setNetworkAccessAllowed:) set { isNetworkAccessAllowed = newValue }
    }
}
extension PHImageManager {
    /// the orientation as CGImagePropertyOrientation's raw value (ImageIO's C enum)
    @objc(requestImageDataAndOrientationForAsset:options:resultHandler:) @discardableResult
    func _objcRequestImageDataAndOrientation(for asset: PHAsset, options: PHImageRequestOptions?,
                                             resultHandler: @escaping (Data?, String?, UInt32, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        requestImageDataAndOrientation(for: asset, options: options) { d, uti, o, info in resultHandler(d, uti, o.rawValue, info) }
    }
}
