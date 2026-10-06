// PHImageManager (images decoded from the library files, scaled to the requested size) and the photo grid used for
// limited-access selection (and by isim's PhotosUI picker).
import UIKit

open class PHImageRequestOptions: NSObject, NSCopying, @unchecked Sendable {
    open var version: PHImageRequestOptionsVersion = .current
    open var deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    open var resizeMode: PHImageRequestOptionsResizeMode = .fast
    open var normalizedCropRect: CGRect = .zero
    open var isNetworkAccessAllowed = false
    open var isSynchronous = false
    open var allowSecondaryDegradedImage = false
    open var progressHandler: ((Double, Error?, UnsafeMutablePointer<ObjCBool>, [AnyHashable: Any]?) -> Void)?
    public override init() { super.init() }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
}

open class PHImageManager: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static let shared = PHImageManager()
    nonisolated(unsafe) static var nextID: PHImageRequestID = 1
    nonisolated(unsafe) static var cancelled = Set<PHImageRequestID>()
    open class func `default`() -> PHImageManager { shared }
    public override init() { super.init() }

    static func newID() -> PHImageRequestID { let i = nextID; nextID += 1; return i }

    static func image(_ asset: PHAsset, _ target: CGSize, _ mode: PHImageContentMode) -> UIImage? {
        guard let img = UIImage(contentsOfFile: _PHStore.path(asset.rec)) else { return nil }
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
    open func requestImageDataAndOrientation(for asset: PHAsset, options: PHImageRequestOptions?,
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
    open func cancelImageRequest(_ requestID: PHImageRequestID) { Self.cancelled.insert(requestID) }
}

public enum CGImagePropertyOrientation: UInt32, Sendable { case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left }

open class PHCachingImageManager: PHImageManager, @unchecked Sendable {
    open var allowsCachingHighQualityImages = true
    public override init() { super.init() }
    open func startCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) {}
    open func stopCachingImages(for assets: [PHAsset], targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) {}
    open func stopCachingImagesForAllAssets() {}
}

open class PHAssetResource: NSObject, @unchecked Sendable {
    public let type: PHAssetResourceType
    public let assetLocalIdentifier: String
    public let originalFilename: String
    public let uniformTypeIdentifier: String
    init(_ a: PHAsset) {
        type = .photo; assetLocalIdentifier = a.localIdentifier; originalFilename = (a.rec.file as NSString).lastPathComponent
        uniformTypeIdentifier = originalFilename.lowercased().hasSuffix(".png") ? "public.png" : "public.jpeg"
    }
    open class func assetResources(for asset: PHAsset) -> [PHAssetResource] { [PHAssetResource(asset)] }
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
    public required init?(coder: NSCoder) { fatalError() }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = _Privacy.barButton("Cancel", id: "photos-cancel", self, #selector(isimPHGridCancel))
        if limit != 1 || !autoConfirmSingle {
            navigationItem.rightBarButtonItem = _Privacy.barButton(confirmTitle, bold: true, id: "photos-done", self, #selector(isimPHGridDone))
        }
        let l = UICollectionViewFlowLayout()
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
        let badge: UILabel
        if let b = cell.contentView.viewWithTag(78) as? UILabel { badge = b } else {
            badge = UILabel(frame: CGRect(x: cell.bounds.width - 28, y: cell.bounds.height - 28, width: 22, height: 22))
            badge.tag = 78; badge.textAlignment = .center; badge.textColor = .white; badge.backgroundColor = .systemBlue
            badge.font = .systemFont(ofSize: 13, weight: .bold); badge.layer.cornerRadius = 11; badge.clipsToBounds = true
            cell.contentView.addSubview(badge)
        }
        let pos = selected.firstIndex(of: a.localIdentifier)
        badge.isHidden = pos == nil
        badge.text = pos.map { limit == 1 ? "✓" : "\($0 + 1)" }
        cell.accessibilityIdentifier = "photo-\(indexPath.item)"
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
    @_spi(isim) public var _isimFilePath: String { _PHStore.path(rec) }
    @_spi(isim) public static func _isimAll() -> [PHAsset] { PHAsset.fetch(_PHStore.records(), nil).items }
}
