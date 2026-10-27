// isim Photos: Live Photos (issue #372). A Live Photo is a still image and a paired movie: PHAssetCreationRequest saves
// one from a .photo and a .pairedVideo resource (the movie is kept beside the image in DCIM), PHImageManager's
// requestLivePhoto and PHLivePhoto.request(withResourceFileURLs:…) hand out PHLivePhotos, which PhotosUI's
// PHLivePhotoView shows and plays. Adapted: Live Photo editing (PHLivePhotoEditingContext) is not there.
import UIKit
import AVFoundation

public typealias PHLivePhotoRequestID = Int32
public let PHLivePhotoRequestIDInvalid: PHLivePhotoRequestID = 0
public let PHLivePhotoInfoErrorKey = "PHLivePhotoInfoErrorKey"
public let PHLivePhotoInfoIsDegradedKey = "PHLivePhotoInfoIsDegradedKey"
public let PHLivePhotoInfoCancelledKey = "PHLivePhotoInfoCancelledKey"

/// A still image and its paired movie.
@objc(PHLivePhoto) open class PHLivePhoto: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    /// the files (in the library, or the app's own for request(withResourceFileURLs:…)), for PhotosUI
    @_spi(isim) public let _imageURL: URL
    @_spi(isim) public let _videoURL: URL
    @objc public let size: CGSize
    let placeholder: UIImage?

    init(image: URL, video: URL, size: CGSize, placeholder: UIImage? = nil) {
        _imageURL = image; _videoURL = video; self.size = size; self.placeholder = placeholder
        super.init()
    }
    /// the Live Photo of a library record (nil when it is not one)
    convenience init?(record r: _PHRecord) {
        guard !r.live.isEmpty else { return nil }
        self.init(image: URL(fileURLWithPath: _PHStore.path(r)), video: URL(fileURLWithPath: (_PHStore.media as NSString).appendingPathComponent(r.live)),
                  size: CGSize(width: r.width, height: r.height))
    }
    /// the Live Photo of a library asset (nil when it is not one)
    @_spi(isim) public static func _isimLivePhoto(of asset: PHAsset) -> PHLivePhoto? {
        PHLivePhoto(record: _PHStore.records().first { $0.id == asset.localIdentifier } ?? asset.rec)
    }
    /// the still image
    @_spi(isim) public var _image: UIImage? { UIImage(contentsOfFile: _imageURL.path) ?? placeholder }

    @nonobjc nonisolated(unsafe) static var nextID: PHLivePhotoRequestID = 1
    @nonobjc nonisolated(unsafe) static var cancelled = Set<PHLivePhotoRequestID>()

    /// A Live Photo from an image file and a movie file (in either order), on the main queue: first the placeholder
    /// (degraded) when one is given, then the Live Photo.
    @discardableResult
    @objc(requestLivePhotoWithResourceFileURLs:placeholderImage:targetSize:contentMode:resultHandler:)
    open class func request(withResourceFileURLs fileURLs: [URL], placeholderImage image: UIImage?, targetSize: CGSize,
                            contentMode: PHImageContentMode, resultHandler: @escaping (PHLivePhoto?, [AnyHashable: Any]) -> Void) -> PHLivePhotoRequestID {
        let id = nextID; nextID += 1
        let movies: Set<String> = ["mov", "mp4", "m4v", "qt"]
        let video = fileURLs.first { movies.contains($0.pathExtension.lowercased()) }
        let still = fileURLs.first { !movies.contains($0.pathExtension.lowercased()) }
        DispatchQueue.main.async {
            if cancelled.contains(id) { resultHandler(nil, [PHLivePhotoInfoCancelledKey: true]); return }
            guard let still, let video, FileManager.default.fileExists(atPath: still.path), FileManager.default.fileExists(atPath: video.path),
                  let img = UIImage(contentsOfFile: still.path) else {
                resultHandler(nil, [PHLivePhotoInfoErrorKey: PHPhotosError(.invalidResource)]); return
            }
            let px = CGSize(width: img.size.width * img.scale, height: img.size.height * img.scale)
            if let image {
                resultHandler(PHLivePhoto(image: still, video: video, size: px, placeholder: image), [PHLivePhotoInfoIsDegradedKey: true])
            }
            resultHandler(PHLivePhoto(image: still, video: video, size: px), [PHLivePhotoInfoIsDegradedKey: false])
        }
        return id
    }
    @objc(cancelLivePhotoRequestWithRequestID:) open class func cancelRequest(withRequestID requestID: PHLivePhotoRequestID) {
        cancelled.insert(requestID)
    }

    @objc public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) {
        coder.encode(_imageURL.path, forKey: "image"); coder.encode(_videoURL.path, forKey: "video")
        coder.encode(size.width, forKey: "width"); coder.encode(size.height, forKey: "height")
    }
    @objc public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: NSString.self, forKey: "image") as String?,
              let v = coder.decodeObject(of: NSString.self, forKey: "video") as String? else { return nil }
        _imageURL = URL(fileURLWithPath: i); _videoURL = URL(fileURLWithPath: v)
        size = CGSize(width: coder.decodeDouble(forKey: "width"), height: coder.decodeDouble(forKey: "height"))
        placeholder = nil
        super.init()
    }
    @objc open override var description: String { "<PHLivePhoto: \(Int(size.width))x\(Int(size.height))>" }
}

@objc(PHLivePhotoRequestOptions) open class PHLivePhotoRequestOptions: NSObject, NSCopying, @unchecked Sendable {
    @objc open var version: PHImageRequestOptionsVersion = .current
    @objc open var deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    @nonobjc open var isNetworkAccessAllowed = false
    @objc(isNetworkAccessAllowed) var _objcNetworkAccessAllowed: Bool {
        get { isNetworkAccessAllowed }
        @objc(setNetworkAccessAllowed:) set { isNetworkAccessAllowed = newValue }
    }
    @objc open var progressHandler: ((Double, Error?, UnsafeMutablePointer<ObjCBool>, [AnyHashable: Any]?) -> Void)?
    @objc open var preferHDR = false
    @objc public override init() { super.init() }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any {
        let o = PHLivePhotoRequestOptions()
        o.version = version; o.deliveryMode = deliveryMode; o.isNetworkAccessAllowed = isNetworkAccessAllowed
        o.progressHandler = progressHandler; o.preferHDR = preferHDR
        return o
    }
}

extension PHImageManager {
    /// The Live Photo of an asset, on the main queue (nil with an error for other assets).
    @discardableResult
    @objc(requestLivePhotoForAsset:targetSize:contentMode:options:resultHandler:)
    public func requestLivePhoto(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHLivePhotoRequestOptions?,
                                 resultHandler: @escaping (PHLivePhoto?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let id = Self.newID()
        let rec = _PHStore.records().first { $0.id == asset.localIdentifier } ?? asset.rec
        DispatchQueue.main.async {
            var info: [AnyHashable: Any] = [PHImageResultRequestIDKey: id, PHImageResultIsInCloudKey: false, PHImageResultIsDegradedKey: false]
            if Self.cancelled.contains(id) { info[PHImageCancelledKey] = true; resultHandler(nil, info); return }
            if let progress = options?.progressHandler { var stop = ObjCBool(false); progress(1, nil, &stop, nil) }
            guard let live = PHLivePhoto(record: rec) else {
                info[PHImageErrorKey] = PHPhotosError(.requestNotSupportedForAsset); resultHandler(nil, info); return
            }
            resultHandler(live, info)
        }
        return id
    }
}

extension _PHStore {
    /// keeps a Live Photo's movie beside its image (IMG_0007.JPG, IMG_0007.MOV)
    static func pairVideo(_ id: String, _ movie: URL) throws {
        guard let rec = records().first(where: { $0.id == id }) else { throw PHPhotosError(.invalidResource) }
        let name = "\((rec.file as NSString).deletingPathExtension).MOV"
        let dest = (media as NSString).appendingPathComponent(name)
        try? FileManager.default.removeItem(atPath: dest)
        try FileManager.default.copyItem(atPath: movie.path, toPath: dest)
        update { recs in if let i = recs.firstIndex(where: { $0.id == id }) { recs[i].live = name } }
    }
}
