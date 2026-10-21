// PHImageManager (images decoded from the library files, scaled to the requested size; videos as AVURLAssets over
// the library's movie files), asset resources and PHAssetResourceManager, and the photo grid used for limited-access
// selection (and by isim's PhotosUI picker).
import UIKit
import AVFoundation

@objc(PHImageRequestOptions) open class PHImageRequestOptions: NSObject, NSCopying, @unchecked Sendable {
    @objc open var version: PHImageRequestOptionsVersion = .current
    @objc open var deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    @objc open var resizeMode: PHImageRequestOptionsResizeMode = .fast
    @objc open var normalizedCropRect: CGRect = .zero
    @nonobjc open var isNetworkAccessAllowed = false
    @nonobjc open var isSynchronous = false
    @objc open var allowSecondaryDegradedImage = false
    @objc open var progressHandler: ((Double, Error?, UnsafeMutablePointer<ObjCBool>, [AnyHashable: Any]?) -> Void)?
    @objc public override init() { super.init() }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}

@objc(PHImageManager) open class PHImageManager: NSObject, @unchecked Sendable {
    @objc static let shared = PHImageManager()
    @objc nonisolated(unsafe) static var nextID: PHImageRequestID = 1
    @objc nonisolated(unsafe) static var cancelled = Set<PHImageRequestID>()
    @objc(defaultManager) open class func `default`() -> PHImageManager { shared }
    @objc public override init() { super.init() }

    @objc static func newID() -> PHImageRequestID { let i = nextID; nextID += 1; return i }

    @objc static func image(_ asset: PHAsset, _ target: CGSize, _ mode: PHImageContentMode) -> UIImage? {
        guard let img = UIImage(contentsOfFile: _PHStore.imagePath(asset.rec)) else { return nil }
        if target.width <= 0 || target.height <= 0 { return img }
        let w = CGFloat(asset.pixelWidth > 0 ? asset.pixelWidth : Int(img.size.width)), h = CGFloat(asset.pixelHeight > 0 ? asset.pixelHeight : Int(img.size.height))
        let s = mode == .aspectFill ? max(target.width / w, target.height / h) : min(target.width / w, target.height / h)
        if s >= 1 { return img }
        let size = CGSize(width: (w * s).rounded(), height: (h * s).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }

    @discardableResult
    @objc(requestImageForAsset:targetSize:contentMode:options:resultHandler:)
    open func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?,
                           resultHandler: @escaping (UIImage?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let id = Self.newID()
        let work = {
            if Self.cancelled.contains(id) { resultHandler(nil, [PHImageCancelledKey: true, PHImageResultRequestIDKey: id]); return }
            let img = Self.image(asset, targetSize, contentMode)
            var info: [AnyHashable: Any] = [PHImageResultIsDegradedKey: false, PHImageResultRequestIDKey: id, PHImageResultIsInCloudKey: false]
            if img == nil { info[PHImageErrorKey] = PHPhotosError(.missingResource) }
            resultHandler(img, info)
        }
        if options?.isSynchronous == true { work() } else { DispatchQueue.main.async(execute: work) }   // async requests answer on the main queue
        return id
    }
    @discardableResult
    @nonobjc open func requestImageDataAndOrientation(for asset: PHAsset, options: PHImageRequestOptions?,
                                             resultHandler: @escaping (Data?, String?, CGImagePropertyOrientation, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let id = Self.newID()
        let work = {
            let path = _PHStore.path(asset.rec)
            let d = FileManager.default.contents(atPath: path)
            let uti = path.lowercased().hasSuffix(".png") ? "public.png" : "public.jpeg"
            resultHandler(d, d == nil ? nil : uti, .up, [PHImageResultRequestIDKey: id, PHImageResultIsInCloudKey: false])
        }
        if options?.isSynchronous == true { work() } else { DispatchQueue.main.async(execute: work) }
        return id
    }
    @objc open func cancelImageRequest(_ requestID: PHImageRequestID) { Self.cancelled.insert(requestID) }

    // MARK: videos (the handlers run on a background queue, as on iOS)

    /// the library file of a video asset, or the info dictionary of the failure
    static func video(_ asset: PHAsset, _ id: PHImageRequestID) -> (URL?, [AnyHashable: Any]) {
        var info: [AnyHashable: Any] = [PHImageResultRequestIDKey: id, PHImageResultIsInCloudKey: false]
        if cancelled.contains(id) { info[PHImageCancelledKey] = true; return (nil, info) }
        let path = _PHStore.path(asset.rec)
        guard asset.mediaType == .video, FileManager.default.fileExists(atPath: path) else {
            info[PHImageErrorKey] = PHPhotosError(asset.mediaType == .video ? .missingResource : .requestNotSupportedForAsset)
            return (nil, info)
        }
        return (URL(fileURLWithPath: path), info)
    }
    @objc static func videoRequest(_ options: PHVideoRequestOptions?, _ work: @escaping () -> Void) {
        DispatchQueue.global().async {
            if let progress = options?.progressHandler { var stop = ObjCBool(false); progress(1, nil, &stop, nil) }
            work()
        }
    }
    @discardableResult
    @objc(requestAVAssetForVideo:options:resultHandler:)
    open func requestAVAsset(forVideo asset: PHAsset, options: PHVideoRequestOptions?,
                             resultHandler: @escaping (AVAsset?, AVAudioMix?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let id = Self.newID()
        Self.videoRequest(options) {
            let (url, info) = Self.video(asset, id)
            resultHandler(url.map { AVURLAsset(url: $0) }, nil, info)
        }
        return id
    }
    @discardableResult
    @objc(requestPlayerItemForVideo:options:resultHandler:)
    open func requestPlayerItem(forVideo asset: PHAsset, options: PHVideoRequestOptions?,
                                resultHandler: @escaping (AVPlayerItem?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let id = Self.newID()
        Self.videoRequest(options) {
            let (url, info) = Self.video(asset, id)
            resultHandler(url.map { AVPlayerItem(asset: AVURLAsset(url: $0)) }, info)
        }
        return id
    }
    @discardableResult
    @objc(requestExportSessionForVideo:options:exportPreset:resultHandler:)
    open func requestExportSession(forVideo asset: PHAsset, options: PHVideoRequestOptions?, exportPreset: String,
                                   resultHandler: @escaping (AVAssetExportSession?, [AnyHashable: Any]?) -> Void) -> PHImageRequestID {
        let id = Self.newID()
        Self.videoRequest(options) {
            let (url, info) = Self.video(asset, id)
            resultHandler(url.flatMap { AVAssetExportSession(asset: AVURLAsset(url: $0), presetName: exportPreset) }, info)
        }
        return id
    }
}

@objc public enum PHVideoRequestOptionsVersion: Int, Sendable { case current = 0, original = 1 }
@objc public enum PHVideoRequestOptionsDeliveryMode: Int, Sendable { case automatic = 0, highQualityFormat = 1, mediumQualityFormat = 2, fastFormat = 3 }
public typealias PHAssetVideoProgressHandler = (Double, Error?, UnsafeMutablePointer<ObjCBool>, [AnyHashable: Any]?) -> Void

/// isim keeps one version of each video (no edits, no iCloud): every option gets the library file
@objc(PHVideoRequestOptions) open class PHVideoRequestOptions: NSObject, @unchecked Sendable {
    @nonobjc open var isNetworkAccessAllowed = false
    @objc open var version: PHVideoRequestOptionsVersion = .current
    @objc open var deliveryMode: PHVideoRequestOptionsDeliveryMode = .automatic
    @objc open var progressHandler: PHAssetVideoProgressHandler?
    @objc public override init() { super.init() }
}

public enum CGImagePropertyOrientation: UInt32, Sendable { case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left }

@objc(PHCachingImageManager) open class PHCachingImageManager: PHImageManager, @unchecked Sendable {
    @objc open var allowsCachingHighQualityImages = true
    @objc public override init() { super.init() }
    @objc(startCachingImagesForAssets:targetSize:contentMode:options:) open func startCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) {}
    @objc(stopCachingImagesForAssets:targetSize:contentMode:options:) open func stopCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) {}
    @objc open func stopCachingImagesForAllAssets() {}
}

@objc(PHAssetResource) open class PHAssetResource: NSObject, @unchecked Sendable {
    @objc public let type: PHAssetResourceType
    @objc public let assetLocalIdentifier: String
    @objc public let originalFilename: String
    @objc public let uniformTypeIdentifier: String
    @objc let path: String
    @objc init(_ a: PHAsset) {
        assetLocalIdentifier = a.localIdentifier; originalFilename = (a.rec.file as NSString).lastPathComponent
        path = _PHStore.path(a.rec)
        let ext = (originalFilename as NSString).pathExtension.lowercased()
        type = a.mediaType == .video ? .video : .photo
        uniformTypeIdentifier = ["png": "public.png", "heic": "public.heic", "mov": "com.apple.quicktime-movie", "mp4": "public.mpeg-4",
                                 "m4v": "com.apple.m4v-video"][ext] ?? "public.jpeg"
    }
    /// the asset's one resource: its photo or its video (isim keeps no paired or adjusted resources)
    @objc(assetResourcesForAsset:) open class func assetResources(for asset: PHAsset) -> [PHAssetResource] { [PHAssetResource(asset)] }
}

public typealias PHAssetResourceDataRequestID = Int32
public typealias PHAssetResourceProgressHandler = (Double) -> Void

@objc(PHAssetResourceRequestOptions) open class PHAssetResourceRequestOptions: NSObject, NSCopying, @unchecked Sendable {
    @nonobjc open var isNetworkAccessAllowed = false
    @objc open var progressHandler: PHAssetResourceProgressHandler?
    @objc public override init() { super.init() }
    @objc public func copy(with zone: OpaquePointer? = nil) -> Any {
        let o = PHAssetResourceRequestOptions(); o.isNetworkAccessAllowed = isNetworkAccessAllowed; o.progressHandler = progressHandler; return o
    }
}

/// A resource's bytes from the library file, in chunks on a background queue (adapted: everything is local).
@objc(PHAssetResourceManager) open class PHAssetResourceManager: NSObject, @unchecked Sendable {
    @objc static let shared = PHAssetResourceManager()
    @objc nonisolated(unsafe) static var nextID: PHAssetResourceDataRequestID = 1
    @objc nonisolated(unsafe) static var cancelled = Set<PHAssetResourceDataRequestID>()
    @objc static let lock = NSLock()
    @objc static let chunk = 256 * 1024
    @objc(defaultManager) open class func `default`() -> PHAssetResourceManager { shared }
    @objc public override init() { super.init() }

    @discardableResult
    @objc(requestDataForAssetResource:options:dataReceivedHandler:completionHandler:)
    open func requestData(for resource: PHAssetResource, options: PHAssetResourceRequestOptions?,
                          dataReceivedHandler handler: @escaping (Data) -> Void, completionHandler: @escaping (Error?) -> Void) -> PHAssetResourceDataRequestID {
        Self.lock.lock(); let id = Self.nextID; Self.nextID += 1; Self.lock.unlock()
        DispatchQueue.global().async {
            guard let fh = FileHandle(forReadingAtPath: resource.path) else { completionHandler(PHPhotosError(.missingResource)); return }
            defer { fh.closeFile() }
            let total = Double((try? FileManager.default.attributesOfItem(atPath: resource.path)[.size] as? NSNumber)??.doubleValue ?? 0)
            var sent = 0.0
            while true {
                Self.lock.lock(); let stop = Self.cancelled.contains(id); Self.lock.unlock()
                if stop { completionHandler(PHPhotosError(.userCancelled)); return }
                let d = fh.readData(ofLength: Self.chunk)
                if d.isEmpty { break }
                handler(d)
                sent += Double(d.count)
                options?.progressHandler?(total > 0 ? min(1, sent / total) : 1)
            }
            completionHandler(nil)
        }
        return id
    }
    @objc open func cancelDataRequest(_ requestID: PHAssetResourceDataRequestID) {
        Self.lock.lock(); Self.cancelled.insert(requestID); Self.lock.unlock()
    }
    /// fails when a file already exists at fileURL, as on iOS
    @objc(writeDataForAssetResource:toFile:options:completionHandler:)
    open func writeData(for resource: PHAssetResource, toFile fileURL: URL, options: PHAssetResourceRequestOptions?,
                        completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.global().async {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [NSFilePathErrorKey: fileURL.path])); return
            }
            do {
                try FileManager.default.copyItem(atPath: resource.path, toPath: fileURL.path)
                options?.progressHandler?(1)
                completionHandler(nil)
            } catch { completionHandler(error) }
        }
    }
    @nonobjc open func writeData(for resource: PHAssetResource, toFile fileURL: URL, options: PHAssetResourceRequestOptions?) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            writeData(for: resource, toFile: fileURL, options: options) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
}

// MARK: - Photo grid (limited selection; reused by PhotosUI)

/// A grid of the whole photo library (the system shows it, so no app permission is needed), single or multiple selection.
@_spi(isim) open class _ISIMPhotoGridController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    public let assets: [PHAsset]
    public var selected: [String]
    public let limit: Int
    public let confirmTitle: String
    public var onDone: (([String]) -> Void)?
    public var onCancel: (() -> Void)?
    public var autoConfirmSingle = true
    var grid: UICollectionView!

    public init(title: String, selected: [String], limit: Int, confirmTitle: String = "Add") {
        assets = PHAsset.fetch(_PHStore.records(), nil).items
        self.selected = selected; self.limit = limit; self.confirmTitle = confirmTitle
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    /// including: which assets the grid offers (PHPickerFilter); all of them when nil
    public init(title: String, selected: [String], limit: Int, confirmTitle: String = "Add", including: ((PHAsset) -> Bool)?) {
        assets = PHAsset.fetch(_PHStore.records(), nil).items.filter { including?($0) ?? true }
        self.selected = selected; self.limit = limit; self.confirmTitle = confirmTitle
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    public required init?(coder: NSCoder) { fatalError() }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = _Privacy.barButton("Cancel", id: "photos-cancel", self, #selector(isimPHGridCancel))
        if limit != 1 || !autoConfirmSingle {
            navigationItem.rightBarButtonItem = _Privacy.barButton(confirmTitle, bold: true, id: "photos-done", self, #selector(isimPHGridDone))
        }
        let l = _ISIMLeftAlignedFlowLayout()
        let side = ((view.bounds.width - 6) / 4).rounded(.down)
        l.itemSize = CGSize(width: side, height: side); l.minimumLineSpacing = 2; l.minimumInteritemSpacing = 2
        grid = UICollectionView(frame: view.bounds, collectionViewLayout: l)
        grid.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        grid.backgroundColor = .systemBackground
        grid.dataSource = self; grid.delegate = self
        grid.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "p")
        view.addSubview(grid)
    }
    @objc func isimPHGridCancel() { onCancel?() }
    @objc func isimPHGridDone() { onDone?(selected) }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { assets.count }
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "p", for: indexPath)
        let iv: UIImageView
        if let v = cell.contentView.viewWithTag(77) as? UIImageView { iv = v } else {
            iv = UIImageView(frame: cell.contentView.bounds)
            iv.tag = 77; iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true
            iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cell.contentView.addSubview(iv)
        }
        let a = assets[indexPath.item]
        iv.image = PHImageManager.image(a, CGSize(width: 200, height: 200), .aspectFill)
        // a new cell has no size yet: lay out from the layout's
        let size = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize ?? cell.bounds.size
        let badge: UILabel
        if let b = cell.contentView.viewWithTag(78) as? UILabel { badge = b } else {
            badge = UILabel(frame: CGRect(x: size.width - 28, y: size.height - 28, width: 22, height: 22))
            badge.tag = 78; badge.textAlignment = .center; badge.textColor = .white; badge.backgroundColor = .systemBlue
            badge.font = .systemFont(ofSize: 13, weight: .bold); badge.layer.cornerRadius = 11; badge.clipsToBounds = true
            cell.contentView.addSubview(badge)
        }
        let pos = selected.firstIndex(of: a.localIdentifier)
        badge.isHidden = pos == nil
        badge.text = pos.map { limit == 1 ? "✓" : "\($0 + 1)" }
        // videos show their duration at the bottom right, like Photos
        let duration: UILabel
        if let d = cell.contentView.viewWithTag(79) as? UILabel { duration = d } else {
            duration = UILabel(frame: CGRect(x: 4, y: cell.bounds.height - 20, width: cell.bounds.width - 8, height: 16))
            duration.tag = 79; duration.textAlignment = .right; duration.textColor = .white
            duration.font = .systemFont(ofSize: 12, weight: .semibold)
            duration.layer.shadowColor = UIColor.black.cgColor; duration.layer.shadowOpacity = 0.6; duration.layer.shadowRadius = 2
            duration.layer.shadowOffset = .zero
            cell.contentView.addSubview(duration)
        }
        duration.frame = CGRect(x: 4, y: size.height - 20, width: max(0, size.width - 10), height: 16)
        let secs = Int(a.duration.rounded())
        duration.isHidden = a.mediaType != .video || pos != nil
        duration.text = a.mediaType == .video ? String(format: "%d:%02d", secs / 60, secs % 60) : nil
        cell.accessibilityIdentifier = "\(a.mediaType == .video ? "video" : "photo")-\(indexPath.item)"
        return cell
    }
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let id = assets[indexPath.item].localIdentifier
        if limit == 1 && autoConfirmSingle { selected = [id]; onDone?(selected); return }
        if let i = selected.firstIndex(of: id) { selected.remove(at: i) }
        else if limit == 0 || selected.count < limit { selected.append(id) }
        collectionView.reloadData()
    }
}

/// rows start at the leading edge, as in Photos (a flow layout centres a lone item in its row)
final class _ISIMLeftAlignedFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attrs = super.layoutAttributesForElements(in: rect) else { return nil }
        var x = sectionInset.left, row = -CGFloat.greatestFiniteMagnitude
        return attrs.map { a in
            guard a.representedElementCategory == .cell, let e = a.copy() as? UICollectionViewLayoutAttributes else { return a }
            if abs(e.frame.minY - row) > 0.5 { row = e.frame.minY; x = sectionInset.left }
            e.frame.origin.x = x
            x += e.frame.width + minimumInteritemSpacing
            return e
        }
    }
}

/// limited-access selection ("Select Photos")
enum _PHSelection {
    @MainActor static func present(selected: Set<String>, done: @escaping (Set<String>) -> Void) {
        guard let top = _Privacy.topController() else { done(selected); return }
        let g = _ISIMPhotoGridController(title: "Select Photos", selected: Array(selected), limit: 0, confirmTitle: "Done")
        g.autoConfirmSingle = false
        let nav = UINavigationController(rootViewController: g)
        nav.isModalInPresentation = true
        g.onDone = { ids in _Privacy.dismiss(g) { done(Set(ids)) } }
        g.onCancel = { _Privacy.dismiss(g) { done(selected) } }
        top.present(nav, animated: true, completion: nil)
    }
}

extension PHAsset {
    /// isim: the file holding the asset's image (used by PhotosUI's item providers)
    @objc @_spi(isim) public var _isimFilePath: String { _PHStore.path(rec) }
    /// every photo and video in the library (PHPickerViewController runs outside the app's permission)
    @objc @_spi(isim) public static func _isimAll() -> [PHAsset] { PHAsset.fetch(_PHStore.records(), nil).items }
}
