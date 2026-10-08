// Sample: UIImagePickerController on isim — the photo library (photos with the Move and Scale crop, videos) and the
// simulated camera (ISIM_CAMERA): photos, photos with editing, video capture with the PHOTO / VIDEO switch, custom
// controls (showsCameraControls = false, a cameraOverlayView with its own shutter calling takePicture()), and saving
// the recorded video with UISaveVideoAtPathToSavedPhotosAlbum.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = PickerViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class PickerViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let result = UIImageView(), status = UILabel()
    var lastMovie: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        print("picker sources library=\(UIImagePickerController.isSourceTypeAvailable(.photoLibrary)) camera=\(UIImagePickerController.isSourceTypeAvailable(.camera)) " +
              "front=\(UIImagePickerController.isCameraDeviceAvailable(.front)) flash=\(UIImagePickerController.isFlashAvailable(for: .rear)) " +
              "media=\(UIImagePickerController.availableMediaTypes(for: .camera) ?? [])")
        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 6; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let actions: [(String, String, () -> Void)] = [
            ("Library (edit)", "library-edit", { [unowned self] in present(source: .photoLibrary) { $0.allowsEditing = true } }),
            ("Library videos", "library-video", { [unowned self] in present(source: .photoLibrary) { $0.mediaTypes = ["public.movie"] } }),
            ("Camera", "camera-photo", { [unowned self] in present(source: .camera) { _ in } }),
            ("Camera (edit)", "camera-edit", { [unowned self] in present(source: .camera) { $0.allowsEditing = true } }),
            ("Camera video", "camera-video", { [unowned self] in present(source: .camera) { $0.mediaTypes = ["public.image", "public.movie"]; $0.videoQuality = .typeHigh } }),
            ("Custom controls", "camera-custom", { [unowned self] in present(source: .camera) { p in
                p.showsCameraControls = false
                let overlay = UIView(); overlay.backgroundColor = .clear
                let snap = UIButton(type: .system, primaryAction: UIAction(title: "Snap") { [weak p] _ in p?.takePicture() })
                snap.accessibilityIdentifier = "snap"; snap.backgroundColor = .white; snap.frame = CGRect(x: 20, y: 500, width: 100, height: 44)
                overlay.addSubview(snap)
                p.cameraOverlayView = overlay
                p.cameraDevice = .front
            } }),
            ("Save video", "save-video", { [unowned self] in
                guard let m = lastMovie else { print("no movie to save"); return }
                print("video compatible \(UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(m.path))")
                UISaveVideoAtPathToSavedPhotosAlbum(m.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
            }),
        ]
        for (title, id, run) in actions {
            let b = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in run() })
            b.accessibilityIdentifier = id
            stack.addArrangedSubview(b)
        }
        status.numberOfLines = 0; status.accessibilityIdentifier = "status"; status.font = .systemFont(ofSize: 13)
        result.contentMode = .scaleAspectFit; result.accessibilityIdentifier = "result"; result.backgroundColor = .secondarySystemBackground
        stack.addArrangedSubview(status)
        view.addSubview(result)
        result.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            result.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 12),
            result.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            result.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            result.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    func present(source: UIImagePickerController.SourceType, _ configure: (UIImagePickerController) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else { print("source \(source.rawValue) unavailable"); return }
        let p = UIImagePickerController()
        p.sourceType = source
        p.delegate = self
        configure(p)
        present(p, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let type = info[.mediaType] as? String ?? "?"
        if type == "public.movie", let url = info[.mediaURL] as? URL {
            let size = (try? Data(contentsOf: url))?.count ?? 0
            lastMovie = url
            print("picked movie \(url.pathExtension.uppercased()) bytes>0=\(size > 0) source=\(picker.sourceType.rawValue)")
            status.text = "movie \(url.lastPathComponent)"
        } else {
            let original = info[.originalImage] as? UIImage, edited = info[.editedImage] as? UIImage
            let crop = (info[.cropRect] as? NSValue)?.cgRectValue
            let meta = (info[.mediaMetadata] as? [String: Any])?.keys.sorted() ?? []
            print("picked image \(Int(original?.size.width ?? 0))x\(Int(original?.size.height ?? 0)) edited=\(edited.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none") " +
                  "crop=\(crop.map { "\(Int($0.width))x\(Int($0.height))" } ?? "none") url=\(info[.imageURL] != nil) meta=\(meta) source=\(picker.sourceType.rawValue)")
            result.image = edited ?? original
            status.text = "image \(Int((edited ?? original)?.size.width ?? 0)) pt wide"
        }
        picker.dismiss(animated: true)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("picker cancelled source=\(picker.sourceType.rawValue)")
        picker.dismiss(animated: true)
    }
    @objc func video(_ path: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        print("video saved error=\(error.map { "\($0)" } ?? "none")")
    }
}
