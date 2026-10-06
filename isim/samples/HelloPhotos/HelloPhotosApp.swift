// Sample: photos and camera on isim — SwiftUI PhotosPicker + loadTransferable, PHPickerViewController with
// NSItemProvider, UIImagePickerController (photo library; no camera, like the Simulator), the Photos permission
// alert, PHAsset fetching, PHImageManager, saving with PHAssetChangeRequest and UIImageWriteToSavedPhotosAlbum,
// and AVCaptureDevice (no cameras; the camera permission alert).
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
    @Published var status = "—"
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
                Section("Camera") {
                    Button("Use Camera") { model.camera() }.accessibilityIdentifier("camera")
                }
            }
            .navigationTitle("Photos")
        }
    }
}
