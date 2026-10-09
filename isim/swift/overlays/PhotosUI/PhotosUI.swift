// isim PhotosUI (self-authored, iOS API names): PHPickerViewController (a grid of the device photo library; like iOS
// it runs outside the app's photo permission and hands back NSItemProviders), and SwiftUI's PhotosPicker /
// .photosPicker(isPresented:) with PhotosPickerItem.loadTransferable. Images only (adapted).
@_exported import Photos
@_exported import CoreTransferable
@_exported import UniformTypeIdentifiers
@_spi(isim) import Photos
import SwiftUI
import UIKit

// MARK: - SwiftUI Image is Transferable (SwiftUI on iOS)

extension Image: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let img = UIImage(data: data) else { throw NSError(domain: NSItemProviderErrorDomain, code: -1000, userInfo: nil) }
            return Image(uiImage: img)
        }
    }
}

// MARK: - PHPicker

public struct PHPickerFilter: Hashable, Sendable {
    let kinds: Set<String>          // "image", "video", "livePhoto", "screenshot", ...
    let negated: Bool
    init(_ k: Set<String>, negated: Bool = false) { kinds = k; self.negated = negated }
    public static let images = PHPickerFilter(["image"])
    public static let videos = PHPickerFilter(["video"])
    public static let livePhotos = PHPickerFilter(["livePhoto"])
    public static let screenshots = PHPickerFilter(["screenshot"])
    public static let panoramas = PHPickerFilter(["panorama"])
    public static let depthEffectPhotos = PHPickerFilter(["depth"])
    public static let bursts = PHPickerFilter(["burst"])
    public static let slomoVideos = PHPickerFilter(["slomo"])
    public static let timelapseVideos = PHPickerFilter(["timelapse"])
    public static let cinematicVideos = PHPickerFilter(["cinematic"])
    public static let spatialMedia = PHPickerFilter(["spatial"])
    public static func any(of subfilters: [PHPickerFilter]) -> PHPickerFilter { PHPickerFilter(subfilters.reduce(into: Set()) { $0.formUnion($1.negated ? [] : $1.kinds) }) }
    public static func all(of subfilters: [PHPickerFilter]) -> PHPickerFilter { any(of: subfilters) }
    public static func not(_ filter: PHPickerFilter) -> PHPickerFilter { PHPickerFilter(filter.kinds, negated: !filter.negated) }
    public static func playbackStyle(_ playbackStyle: Int) -> PHPickerFilter { .images }
    /// every library item is a still image on isim
    var matchesImages: Bool { negated ? !kinds.contains("image") : kinds.contains("image") }
}

public struct PHPickerConfiguration: Sendable {
    public enum AssetRepresentationMode: Int, Sendable { case automatic = 0, current = 1, compatible = 2 }
    public enum Selection: Int, Sendable { case `default` = 0, ordered = 1, continuous = 2, continuousAndOrdered = 3 }
    public struct Update: Sendable {}
    public var preferredAssetRepresentationMode: AssetRepresentationMode = .automatic
    public var selection: Selection = .default
    public var filter: PHPickerFilter?
    public var selectionLimit = 1
    public var preselectedAssetIdentifiers: [String] = []
    public var mode: Int = 0
    public var edgesWithoutContentMargins: Int = 0
    public var disabledCapabilities: Int = 0
    let identifiers: Bool
    public init() { identifiers = false }
    public init(photoLibrary: PHPhotoLibrary) { identifiers = true }
}

public struct PHPickerResult: Hashable, @unchecked Sendable {
    public let itemProvider: NSItemProvider
    public let assetIdentifier: String?
    public static func == (a: PHPickerResult, b: PHPickerResult) -> Bool { a.itemProvider === b.itemProvider }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(itemProvider)) }
}

public protocol PHPickerViewControllerDelegate: AnyObject {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult])
}

enum _PUAssets {
    static func provider(_ asset: PHAsset) -> NSItemProvider {
        let p = NSItemProvider()
        let path = asset._isimFilePath
        let type = path.lowercased().hasSuffix(".png") ? "public.png" : "public.jpeg"
        p.suggestedName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        p.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { done in
            if let d = FileManager.default.contents(atPath: path) { done(d, nil) } else { done(nil, PHPhotosError(.missingResource)) }
            return nil
        }
        return p
    }
}

open class PHPickerViewController: UIViewController {
    public let configuration: PHPickerConfiguration
    open weak var delegate: PHPickerViewControllerDelegate?
    let nav = UINavigationController()
    var finished = false

    public init(configuration: PHPickerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    public required init?(coder: NSCoder) { configuration = PHPickerConfiguration(); super.init(coder: coder) }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let limit = configuration.selectionLimit
        let grid = _ISIMPhotoGridController(title: limit == 1 ? "Photos" : "Select Items", selected: configuration.preselectedAssetIdentifiers, limit: limit)
        grid.onDone = { [weak self] ids in self?.finish(ids) }
        grid.onCancel = { [weak self] in self?.finish([]) }
        nav.viewControllers = [grid]
        addChild(nav)
        nav.view.frame = view.bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(nav.view)
        nav.didMove(toParent: self)
    }
    func finish(_ ids: [String]) {
        guard !finished else { return }
        finished = true
        let all = Dictionary(uniqueKeysWithValues: PHAsset._isimAll().map { ($0.localIdentifier, $0) })
        let results = ids.compactMap { all[$0] }.filter { _ in configuration.filter?.matchesImages ?? true }
            .map { PHPickerResult(itemProvider: _PUAssets.provider($0), assetIdentifier: configuration.identifiers ? $0.localIdentifier : nil) }
        NSLog("isim PhotosUI: picked %d item(s)", results.count)
        if let delegate { delegate.picker(self, didFinishPicking: results) }
        else { presentingViewController?.dismiss(animated: true, completion: nil) }
    }
    open func deselectAssets(withIdentifiers identifiers: [String]) {}
    open func moveAsset(withIdentifier identifier: String, afterAssetWithIdentifier: String?) {}
    open func scrollToInitialPosition() {}
}

// MARK: - SwiftUI

public struct PhotosPickerItem: Equatable, Hashable, Sendable {
    public enum EncodingDisambiguationPolicy: Equatable, Hashable, Sendable { case automatic, current, compatible }
    public let itemIdentifier: String?
    let assetID: String
    let path: String
    public var supportedContentTypes: [UTType] { [path.lowercased().hasSuffix(".png") ? .png : .jpeg] }
    public init(itemIdentifier: String) { self.itemIdentifier = itemIdentifier; assetID = itemIdentifier
        path = PHAsset._isimAll().first { $0.localIdentifier == itemIdentifier }?._isimFilePath ?? "" }
    init(asset: PHAsset, exposeIdentifier: Bool) { itemIdentifier = exposeIdentifier ? asset.localIdentifier : nil; assetID = asset.localIdentifier; path = asset._isimFilePath }
    public static func == (a: PhotosPickerItem, b: PhotosPickerItem) -> Bool { a.assetID == b.assetID }
    public func hash(into h: inout Hasher) { h.combine(assetID) }

    public func loadTransferable<T: Transferable>(type: T.Type) async throws -> T? {
        guard let data = FileManager.default.contents(atPath: path) else { throw PHPhotosError(.missingResource) }
        return try await T._isimImport(data, contentType: supportedContentTypes[0])
    }
    @discardableResult
    public func loadTransferable<T: Transferable>(type: T.Type, completionHandler: @escaping @Sendable (Result<T?, Error>) -> Void) -> Progress {
        let p = Progress(totalUnitCount: 1)
        let item = self
        Task.detached {
            do { let v = try await item.loadTransferable(type: T.self); p.completedUnitCount = 1; completionHandler(.success(v)) }
            catch { completionHandler(.failure(error)) }
        }
        return p
    }
}

@MainActor enum _PUPresenter {
    @MainActor final class Relay: NSObject, @preconcurrency PHPickerViewControllerDelegate {
        let done: ([PhotosPickerItem]) -> Void
        let expose: Bool
        init(expose: Bool, done: @escaping ([PhotosPickerItem]) -> Void) { self.expose = expose; self.done = done }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let ids = picker.pickedIDs
            let all = Dictionary(uniqueKeysWithValues: PHAsset._isimAll().map { ($0.localIdentifier, $0) })
            let items = ids.compactMap { all[$0] }.map { PhotosPickerItem(asset: $0, exposeIdentifier: expose) }
            picker.dismiss(animated: true) { [done] in done(items) }
            relay = nil
        }
    }
    static var relay: Relay?
    static func present(limit: Int, filter: PHPickerFilter?, preselected: [PhotosPickerItem], expose: Bool, cancelled: (() -> Void)? = nil, done: @escaping ([PhotosPickerItem]) -> Void) {
        guard let top = _Privacy.topController() else { return }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = limit; config.filter = filter
        config.preselectedAssetIdentifiers = preselected.map(\.assetID)
        let vc = PHPickerViewController(configuration: config)
        let r = Relay(expose: expose) { items in
            if items.isEmpty { cancelled?() } else { done(items) }
        }
        relay = r
        vc.delegate = r
        top.present(vc, animated: true, completion: nil)
    }
}

extension PHPickerViewController {
    /// the identifiers chosen in this picker (isim: recorded for PhotosPicker)
    var pickedIDs: [String] { (nav.viewControllers.first as? _ISIMPhotoGridController)?.selected ?? [] }
}

public enum PhotosPickerSelectionBehavior: Equatable, Hashable, Sendable { case `default`, ordered, continuous, continuousAndOrdered }
public enum PhotosPickerStyle: Equatable, Hashable, Sendable { case presentation, inline, compact }

public struct PhotosPicker<Label: View>: View {
    let single: Binding<PhotosPickerItem?>?
    let multi: Binding<[PhotosPickerItem]>?
    let limit: Int
    let filter: PHPickerFilter?
    let expose: Bool
    let label: Label

    public init(selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil,
                preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, @ViewBuilder label: () -> Label) {
        single = selection; multi = nil; limit = 1; self.filter = filter; expose = false; self.label = label()
    }
    public init(selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil,
                preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, photoLibrary: PHPhotoLibrary, @ViewBuilder label: () -> Label) {
        single = selection; multi = nil; limit = 1; self.filter = filter; expose = true; self.label = label()
    }
    public init(selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default,
                matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, @ViewBuilder label: () -> Label) {
        single = nil; multi = selection; limit = maxSelectionCount ?? 0; self.filter = filter; expose = false; self.label = label()
    }
    public init(selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default,
                matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic,
                photoLibrary: PHPhotoLibrary, @ViewBuilder label: () -> Label) {
        single = nil; multi = selection; limit = maxSelectionCount ?? 0; self.filter = filter; expose = true; self.label = label()
    }

    public var body: some View {
        Button(action: open) { label }
    }
    func open() {
        let single = single, multi = multi
        _PUPresenter.present(limit: limit, filter: filter, preselected: multi?.wrappedValue ?? [], expose: expose) { items in
            if let single { single.wrappedValue = items.first }
            if let multi { multi.wrappedValue = items }
        }
    }
}

extension PhotosPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil,
                preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {
        self.init(selection: selection, matching: filter, preferredItemEncoding: preferredItemEncoding) { Text(titleKey) }
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ title: S, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil,
                                   preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {
        self.init(selection: selection, matching: filter, preferredItemEncoding: preferredItemEncoding) { Text(title) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil,
                selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil,
                preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {
        self.init(selection: selection, maxSelectionCount: maxSelectionCount, selectionBehavior: selectionBehavior, matching: filter,
                  preferredItemEncoding: preferredItemEncoding) { Text(titleKey) }
    }
}

extension View {
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil,
                             preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) -> some View {
        onChange(of: isPresented.wrappedValue) { _, shown in
            guard shown else { return }
            _PUPresenter.present(limit: 1, filter: filter, preselected: [], expose: false, cancelled: { isPresented.wrappedValue = false }) { items in
                selection.wrappedValue = items.first
                isPresented.wrappedValue = false
            }
        }
    }
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil,
                             selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil,
                             preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) -> some View {
        onChange(of: isPresented.wrappedValue) { _, shown in
            guard shown else { return }
            _PUPresenter.present(limit: maxSelectionCount ?? 0, filter: filter, preselected: selection.wrappedValue, expose: false,
                                 cancelled: { isPresented.wrappedValue = false }) { items in
                selection.wrappedValue = items
                isPresented.wrappedValue = false
            }
        }
    }
    public func photosPickerStyle(_ style: PhotosPickerStyle) -> some View { self }
}
