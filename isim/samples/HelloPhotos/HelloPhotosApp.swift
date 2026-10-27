// Sample: photos and camera on isim — SwiftUI PhotosPicker + loadTransferable, PHPickerViewController with
// NSItemProvider, UIImagePickerController (photo library; no camera, like the Simulator), the Photos permission
// alert, PHAsset fetching, PHImageManager, saving with PHAssetChangeRequest and UIImageWriteToSavedPhotosAlbum,
// AVCaptureDevice (no cameras; the camera permission alert), and videos and albums: saving a movie, requestAVAsset /
// requestPlayerItem, PHAssetResourceManager, user albums with PHAssetCollectionChangeRequest, and picking videos;
// Live Photos and edits (LiveAndEdits.swift).
import SwiftUI
import PhotosUI
import AVFoundation

@main
struct HelloPhotosApp: App {
    @StateObject private var model = PhotosModel()
    var body: some Scene { WindowGroup { ContentView(model: model) } }
}

@MainActor func topController() -> UIViewController? {
    var vc = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
    while let p = vc?.presentedViewController { vc = p }
    return vc
}

@MainActor
final class PhotosModel: NSObject, ObservableObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @Published var picked: UIImage?
    let _videoPickerDelegate = VideoPickerDelegate()
    @Published var movie: PhotosPickerItem? {
        didSet { if let movie { loadMovie(movie) } }
    }
    @Published var status = "—"
    @Published var livePhoto: PHLivePhoto?
    let livePhotoView = PHLivePhotoView()
    let liveDelegate = LiveViewDelegate()
    @Published var item: PhotosPickerItem? {
        didSet { if let item { load(item) } }
    }
    @Published var items: [PhotosPickerItem] = [] {
        didSet { print("photosPicker multi \(items.count) items") }
    }

    func load(_ item: PhotosPickerItem) {
        Task {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                print("photosPicker data \(data?.count ?? 0) bytes types \(item.supportedContentTypes.map(\.identifier)) id \(item.itemIdentifier == nil ? "nil" : "set")")
                if let d = data, let img = UIImage(data: d) { picked = img; print("photosPicker image \(Int(img.size.width))x\(Int(img.size.height))") }
                let image = try await item.loadTransferable(type: Image.self)
                print("photosPicker Image \(image == nil ? "nil" : "ok")")
            } catch { print("photosPicker error \(error)") }
        }
    }

    // MARK: PHPicker
    func showPHPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 2
        config.filter = .images
        let p = PHPickerViewController(configuration: config)
        p.delegate = self
        topController()?.present(p, animated: true)
    }
    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        MainActor.assumeIsolated {
            picker.dismiss(animated: true)
            print("phpicker \(results.count) results, assetIdentifier \(results.first?.assetIdentifier ?? "nil")")
        }
        for r in results {
            let p = r.itemProvider
            print("phpicker canLoad UIImage \(p.canLoadObject(ofClass: UIImage.self)) types \(p.registeredTypeIdentifiers)")
            p.loadObject(ofClass: UIImage.self) { obj, err in
                let img = obj as? UIImage
                print("phpicker loaded \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil") main \(Thread.isMainThread)")
                DispatchQueue.main.async { if let img { self.picked = img } }
            }
        }
    }

    // MARK: UIImagePickerController
    func showImagePicker() {
        print("imagePicker camera available \(UIImagePickerController.isSourceTypeAvailable(.camera)) library \(UIImagePickerController.isSourceTypeAvailable(.photoLibrary))")
        let p = UIImagePickerController()
        p.sourceType = .photoLibrary
        p.delegate = self
        topController()?.present(p, animated: true)
    }
    nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        MainActor.assumeIsolated {
            let img = info[.originalImage] as? UIImage
            print("imagePicker picked \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil") url \((info[.imageURL] as? URL)?.lastPathComponent ?? "-")")
            picked = img
            picker.dismiss(animated: true)
        }
    }
    nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        MainActor.assumeIsolated { print("imagePicker cancelled"); picker.dismiss(animated: true) }
    }

    // MARK: Photos library
    func requestLibrary() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
            print("library status \(s.rawValue) old API \(PHPhotoLibrary.authorizationStatus().rawValue)")
            DispatchQueue.main.async { self.listLibrary() }
        }
    }
    func listLibrary() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: opts)
        status = "\(assets.count) photos"
        print("library \(assets.count) assets first \(assets.firstObject.map { "\($0.pixelWidth)x\($0.pixelHeight)" } ?? "-")")
        guard let first = assets.firstObject else { return }
        PHImageManager.default().requestImage(for: first, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: nil) { img, info in
            print("requestImage \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil") degraded \(info?[PHImageResultIsDegradedKey] as? Bool ?? true) main \(Thread.isMainThread)")
        }
        let favs = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
        if let f = favs.firstObject { print("favorites \(PHAsset.fetchAssets(in: f, options: nil).count) in \(f.localizedTitle ?? "?")") }
    }
    func saveGenerated() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48)).image { ctx in
            UIColor.systemRed.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        }
        var placeholder: String?
        PHPhotoLibrary.shared().performChanges({
            let r = PHAssetChangeRequest.creationRequestForAsset(from: img)
            placeholder = r.placeholderForCreatedAsset?.localIdentifier
        }) { ok, error in
            let found = placeholder.map { PHAsset.fetchAssets(withLocalIdentifiers: [$0], options: nil).count } ?? 0
            print("performChanges saved \(ok) placeholder \(placeholder != nil) refetch \(found) error \((error as? PHPhotosError)?.code.rawValue ?? 0)")
            DispatchQueue.main.async { self.favoriteFirst() }
        }
    }
    func favoriteFirst() {
        guard let first = PHAsset.fetchAssets(with: nil).firstObject else { return }
        PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest(for: first).isFavorite = true }) { ok, _ in
            DispatchQueue.main.async { print("favorite \(ok)"); self.listLibrary() }
        }
    }
    let saver = Saver()
    var videoPickerDelegate: VideoPickerDelegate { _videoPickerDelegate }
    func writeToAlbum() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 20)).image { ctx in
            UIColor.systemGreen.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }
        UIImageWriteToSavedPhotosAlbum(img, saver, #selector(Saver.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    // MARK: camera
    func camera() {
        print("camera device \(AVCaptureDevice.default(for: .video) == nil ? "none" : "found") discovered \(AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.count)")
        AVCaptureDevice.requestAccess(for: .video) { ok in
            print("camera access \(ok) status \(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
        }
        let session = AVCaptureSession()
        session.addOutput(AVCapturePhotoOutput())
        session.startRunning()
        print("capture session running \(session.isRunning) outputs \(session.outputs.count) inputs \(session.inputs.count)")
    }
}

// MARK: - videos and albums

/// a movie file, for PhotosPicker's loadTransferable
struct Movie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let copy = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("picked-\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Movie(url: copy)
        }
    }
}

extension PhotosModel {
    /// a 2 s, 160 x 120 movie of four frames (red, green, blue, blue), half a second each
    nonisolated func writeMovie() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clip.mov")
        try? FileManager.default.removeItem(at: url)
        let w = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 120])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        w.add(input)
        w.startWriting(); w.startSession(atSourceTime: .zero)
        let colors: [(UInt8, UInt8, UInt8)] = [(0, 0, 255), (0, 255, 0), (255, 0, 0)]       // BGR: red, green, blue
        for i in 0 ..< 4 {
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(nil, 160, 120, kCVPixelFormatType_32BGRA, nil, &pb)
            let b = pb!
            CVPixelBufferLockBaseAddress(b, [])
            let base = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to: UInt8.self), bpr = CVPixelBufferGetBytesPerRow(b)
            let c = colors[min(i, 2)]
            for y in 0 ..< 120 { for x in 0 ..< 160 { let p = base + y * bpr + x * 4; p[0] = c.0; p[1] = c.1; p[2] = c.2; p[3] = 255 } }
            CVPixelBufferUnlockBaseAddress(b, [])
            adaptor.append(b, withPresentationTime: CMTime(seconds: Double(i) * 0.5, preferredTimescale: 600))
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        w.finishWriting { done.signal() }
        done.wait()
        return url
    }

    func saveVideo() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            do {
                let movie = try self.writeMovie()
                var placeholder: String?
                try PHPhotoLibrary.shared().performChangesAndWait {
                    placeholder = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movie)?.placeholderForCreatedAsset?.localIdentifier
                }
                let videos = PHAsset.fetchAssets(with: .video, options: nil)
                let v = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder ?? ""], options: nil).firstObject
                print("video saved \(v != nil) videos \(videos.count) duration \(String(format: "%.1f", v?.duration ?? 0)) size \(v?.pixelWidth ?? 0)x\(v?.pixelHeight ?? 0)")
                let predicate = PHFetchOptions()
                predicate.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                print("predicate videos \(PHAsset.fetchAssets(with: predicate).count)")
                if let v { self.inspect(v) }
            } catch { print("video save error \(error)") }
        }
    }

    nonisolated func inspect(_ v: PHAsset) {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .original
        PHImageManager.default().requestAVAsset(forVideo: v, options: options) { asset, mix, info in
            let url = (asset as? AVURLAsset)?.url.lastPathComponent ?? "-"
            print("requestAVAsset \(url) duration \(String(format: "%.1f", asset?.duration.seconds ?? 0)) video tracks \(asset?.tracks(withMediaType: .video).count ?? 0) main \(Thread.isMainThread)")
            PHImageManager.default().requestPlayerItem(forVideo: v, options: nil) { item, _ in
                print("requestPlayerItem \(item != nil) asset \((item?.asset as? AVURLAsset)?.url.lastPathComponent ?? "-")")
                self.resources(v)
            }
        }
    }

    nonisolated func resources(_ v: PHAsset) {
        let rs = PHAssetResource.assetResources(for: v)
        guard let r = rs.first else { print("no resources"); return }
        print("resource type \(r.type == .video ? "video" : "\(r.type.rawValue)") uti \(r.uniformTypeIdentifier) name \(r.originalFilename)")
        let bytes = BytesBox()
        let opts = PHAssetResourceRequestOptions()
        PHAssetResourceManager.default().requestData(for: r, options: opts, dataReceivedHandler: { d in bytes.count += d.count }) { error in
            let out = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("export-\(UUID().uuidString).mov")
            PHAssetResourceManager.default().writeData(for: r, toFile: out, options: nil) { e1 in
                let size = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? NSNumber)??.intValue ?? 0
                PHAssetResourceManager.default().writeData(for: r, toFile: out, options: nil) { e2 in
                    print("resource data \(bytes.count > 0) error \(error == nil ? "none" : "\(error!)") written \(e1 == nil && size == bytes.count) again fails \(e2 != nil)")
                }
            }
        }
    }

    func albums() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            do {
                let photos = PHAsset.fetchAssets(with: .image, options: nil)
                let video = PHAsset.fetchAssets(with: .video, options: nil).firstObject
                var albumID = ""
                try PHPhotoLibrary.shared().performChangesAndWait {
                    let r = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Trips")
                    r.addAssets([photos[0], photos[1]] as NSArray)
                    if let video { r.addAssets([video] as NSArray) }
                    albumID = r.placeholderForCreatedAssetCollection.localIdentifier
                }
                let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
                guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject else { print("album missing"); return }
                print("album created \(albums.count) \(album.localizedTitle ?? "-") assets \(PHAsset.fetchAssets(in: album, options: nil).count) rename \(album.canPerform(.rename)) smart rename \(PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil).firstObject?.canPerform(.rename) ?? true)")
                try PHPhotoLibrary.shared().performChangesAndWait {
                    let r = PHAssetCollectionChangeRequest(for: album, assets: PHAsset.fetchAssets(in: album, options: nil))
                    r?.insertAssets([photos[2]] as NSArray, at: IndexSet(integer: 0))
                    r?.removeAssets(at: IndexSet(integer: 1))          // the first photo, now second
                    r?.title = "Summer Trips"
                }
                let after = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumID], options: nil).firstObject!
                let inAlbum = PHAsset.fetchAssets(in: after, options: nil)
                let ids = inAlbum.objects(at: IndexSet(integersIn: 0 ..< inAlbum.count)).map(\.localIdentifier)
                let expected = [photos[2], photos[1]].map(\.localIdentifier) + (video.map { [$0.localIdentifier] } ?? [])
                print("album edited \(after.localizedTitle ?? "-") order \(ids == expected) count \(ids.count)")
                let byTitle = PHFetchOptions()
                byTitle.predicate = NSPredicate(format: "title = %@", "Summer Trips")
                let containing = video.map { PHAssetCollection.fetchAssetCollectionsContaining($0, with: .album, options: nil).count } ?? -1
                print("album found by title \(PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: byTitle).count) containing video \(containing) top level \(PHCollection.fetchTopLevelUserCollections(with: nil).count)")
                try PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetCollectionChangeRequest.deleteAssetCollections([after] as NSArray)
                }
                print("album deleted \(PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).count == albums.count - 1)")
                // a second album stays, for the screenshot
                try PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Favourites of isim").addAssets(PHAsset.fetchAssets(with: .image, options: nil))
                }
                DispatchQueue.main.async { self.status = "\(PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).count) album(s)" }
            } catch { print("album error \(error)") }
        }
    }

    func loadMovie(_ item: PhotosPickerItem) {
        Task {
            do {
                let m = try await item.loadTransferable(type: Movie.self)
                let size = m.flatMap { (try? FileManager.default.attributesOfItem(atPath: $0.url.path)[.size] as? NSNumber)??.intValue } ?? 0
                print("photosPicker movie \(size > 0) types \(item.supportedContentTypes.map(\.identifier))")
            } catch { print("photosPicker movie error \(error)") }
        }
    }

    func showVideoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.videos, .livePhotos])
        let p = PHPickerViewController(configuration: config)
        p.delegate = videoPickerDelegate
        topController()?.present(p, animated: true)
    }
}

final class BytesBox: @unchecked Sendable { var count = 0 }

final class VideoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        DispatchQueue.main.async { picker.dismiss(animated: true) }
        guard let p = results.first?.itemProvider else { print("video picker nothing"); return }
        print("video picker types \(p.registeredTypeIdentifiers) movie \(p.hasItemConformingToTypeIdentifier(UTType.movie.identifier))")
        p.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            let size = url.flatMap { (try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? NSNumber)??.intValue } ?? 0
            print("video picker file \(size > 0) \(url?.pathExtension ?? "-") error \(error == nil ? "none" : "\(error!)")")
        }
    }
}

final class Saver: NSObject {
    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeMutableRawPointer?) {
        print("writeToAlbum \(error == nil ? "saved" : "error \(error!.code)")")
    }
}

struct ContentView: View {
    @ObservedObject var model: PhotosModel
    var body: some View {
        NavigationStack {
            List {
                Section("Picked") {
                    if let img = model.picked {
                        Image(uiImage: img).resizable().scaledToFit().frame(height: 120).accessibilityIdentifier("pickedImage")
                    } else { Text("Nothing picked").accessibilityIdentifier("nothing") }
                    PhotosPicker("PhotosPicker", selection: $model.item, matching: .images).accessibilityIdentifier("photosPicker")
                    PhotosPicker(selection: $model.items, maxSelectionCount: 3, matching: .images) { Text("Pick Several") }.accessibilityIdentifier("photosPickerMulti")
                    Button("PHPicker (2)") { model.showPHPicker() }.accessibilityIdentifier("phpicker")
                    Button("UIImagePickerController") { model.showImagePicker() }.accessibilityIdentifier("imagePicker")
                }
                Section("Library") {
                    Text(model.status).accessibilityIdentifier("status")
                    Button("Access Library") { model.requestLibrary() }.accessibilityIdentifier("library")
                    Button("Save Generated Photo") { model.saveGenerated() }.accessibilityIdentifier("save")
                    Button("UIImageWriteToSavedPhotosAlbum") { model.writeToAlbum() }.accessibilityIdentifier("writeAlbum")
                }
                Section("Videos & Albums") {
                    Button("Save Video") { model.saveVideo() }.accessibilityIdentifier("saveVideo")
                    Button("Albums") { model.albums() }.accessibilityIdentifier("albums")
                    PhotosPicker("Pick a Video", selection: $model.movie, matching: .videos).accessibilityIdentifier("videoPicker")
                    Button("PHPicker (videos)") { model.showVideoPicker() }.accessibilityIdentifier("phpickerVideo")
                }
                LiveAndEditsSection(model: model)
                Section("Camera") {
                    Button("Use Camera") { model.camera() }.accessibilityIdentifier("camera")
                }
            }
            .navigationTitle("Photos")
        }
    }
}
