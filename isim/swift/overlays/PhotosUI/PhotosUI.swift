// isim PhotosUI (self-authored, iOS API names): PHPickerViewController (a grid of the device photo library; like iOS
// it runs outside the app's photo permission and hands back NSItemProviders: photos as data, videos as files), and
// SwiftUI's PhotosPicker / .photosPicker(isPresented:) with PhotosPickerItem.loadTransferable. Photos, Live Photos
// and videos (adapted: no bursts or screenshots as kinds of their own); PHLivePhotoView (LivePhotoView.swift).
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
    indirect enum Rule: Hashable, Sendable {
        case kind(String)          // "image", "video", "livePhoto", "screenshot", ...
        case not(Rule)
        case any([Rule])
        case all([Rule])
        func matches(_ kinds: Set<String>) -> Bool {
            switch self {
            case .kind(let k): return kinds.contains(k)
            case .not(let r): return !r.matches(kinds)
            case .any(let rs): return rs.contains { $0.matches(kinds) }
            case .all(let rs): return rs.allSatisfy { $0.matches(kinds) }
            }
        }
    }
    let rule: Rule
    init(_ r: Rule) { rule = r }
    public static let images = PHPickerFilter(.kind("image"))
    public static let videos = PHPickerFilter(.kind("video"))
    public static let livePhotos = PHPickerFilter(.kind("livePhoto"))
    public static let screenshots = PHPickerFilter(.kind("screenshot"))
    public static let panoramas = PHPickerFilter(.kind("panorama"))
    public static let depthEffectPhotos = PHPickerFilter(.kind("depth"))
    public static let bursts = PHPickerFilter(.kind("burst"))
    public static let slomoVideos = PHPickerFilter(.kind("slomo"))
    public static let timelapseVideos = PHPickerFilter(.kind("timelapse"))
    public static let cinematicVideos = PHPickerFilter(.kind("cinematic"))
    @available(iOS 18.0, *) public static let spatialMedia = PHPickerFilter(.kind("spatial"))
    public static func any(of subfilters: [PHPickerFilter]) -> PHPickerFilter { PHPickerFilter(.any(subfilters.map(\.rule))) }
    public static func all(of subfilters: [PHPickerFilter]) -> PHPickerFilter { PHPickerFilter(.all(subfilters.map(\.rule))) }
    public static func not(_ filter: PHPickerFilter) -> PHPickerFilter { PHPickerFilter(.not(filter.rule)) }
    public static func playbackStyle(_ playbackStyle: PHAsset.PlaybackStyle) -> PHPickerFilter { PHPickerFilter(.kind("playback\(playbackStyle.rawValue)")) }
    /// the kinds of a library item: isim's are photos (Live Photos too) and videos, with their playback style
    func matches(_ asset: PHAsset) -> Bool {
        var kinds: Set<String> = [asset.mediaType == .video ? "video" : "image", "playback\(asset.playbackStyle.rawValue)"]
        if asset.mediaSubtypes.contains(.photoLive) { kinds.insert("livePhoto") }
        return rule.matches(kinds)
    }
}

/// How the picker is laid out: a full grid, or one compact row (adapted: isim shows the grid for both).
@objc public enum PHPickerMode: Int, Sendable { case `default` = 0, compact = 1 }

/// Parts of the picker an app can turn off (adapted: isim's picker has only its grid, so these change nothing).
public struct PHPickerCapabilities: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let search = PHPickerCapabilities(rawValue: 1 << 0)
    public static let stagingArea = PHPickerCapabilities(rawValue: 1 << 1)
    public static let collectionNavigation = PHPickerCapabilities(rawValue: 1 << 2)
    public static let selectionActions = PHPickerCapabilities(rawValue: 1 << 3)
    public static let sensitivityAnalysisIntervention = PHPickerCapabilities(rawValue: 1 << 4)
}

public struct PHPickerConfiguration: Sendable {
    public enum AssetRepresentationMode: Int, Sendable { case automatic = 0, current = 1, compatible = 2 }
    public enum Selection: Int, Sendable { case `default` = 0, ordered = 1, continuous = 2, continuousAndOrdered = 3 }
    /// Changes to a shown picker (PHPickerViewController.updatePicker(using:)).
    public struct Update: Sendable {
        public var selectionLimit: Int?
        public var edgesWithoutContentMargins: NSDirectionalRectEdge?
        public init() {}
    }
    public var preferredAssetRepresentationMode: AssetRepresentationMode = .automatic
    public var selection: Selection = .default
    public var filter: PHPickerFilter?
    public var selectionLimit = 1
    public var preselectedAssetIdentifiers: [String] = []
    public var mode: PHPickerMode = .default
    public var edgesWithoutContentMargins: NSDirectionalRectEdge = []
    public var disabledCapabilities: PHPickerCapabilities = []
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
    /// the type identifier of a library file
    static func type(_ path: String) -> String {
        ["png": "public.png", "heic": "public.heic", "mov": "com.apple.quicktime-movie", "mp4": "public.mpeg-4", "m4v": "com.apple.m4v-video"][
            (path as NSString).pathExtension.lowercased()] ?? "public.jpeg"
    }
    static func provider(_ asset: PHAsset) -> NSItemProvider {
        let p = NSItemProvider()
        let path = asset._isimFilePath
        let type = type(path)
        p.suggestedName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        if let live = PHLivePhoto._isimOf(asset) {
            // a Live Photo also loads as a PHLivePhoto (canLoadObject(ofClass: PHLivePhoto.self))
            p.registerDataRepresentation(forTypeIdentifier: PHLivePhoto._bundleType, visibility: .all) { done in
                done(try? NSKeyedArchiver.archivedData(withRootObject: live, requiringSecureCoding: true), nil); return nil
            }
        }
        if asset.mediaType == .video {
            // a movie comes as a file (loadFileRepresentation), and as data for loadDataRepresentation
            p.registerFileRepresentation(forTypeIdentifier: type, fileOptions: [], visibility: .all) { done in
                if FileManager.default.fileExists(atPath: path) { done(URL(fileURLWithPath: path), false, nil) } else { done(nil, false, PHPhotosError(.missingResource)) }
                return nil
            }
            return p
        }
        p.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { done in
            if let d = FileManager.default.contents(atPath: path) { done(d, nil) } else { done(nil, PHPhotosError(.missingResource)) }
            return nil
        }
        return p
    }
}

@objc(PHPickerViewController) open class PHPickerViewController: UIViewController {
    public let configuration: PHPickerConfiguration
    open weak var delegate: PHPickerViewControllerDelegate?
    /// Objective-C's delegate and configuration (ObjC.swift; PhotosUI.m has the configuration class)
    weak var _objcDelegate: _PUObjCPickerDelegate?
    var _objcConfiguration: NSObject?
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
        let filter = configuration.filter
        let grid = _ISIMPhotoGridController(title: limit == 1 ? "Photos" : "Select Items", selected: configuration.preselectedAssetIdentifiers, limit: limit,
                                            including: filter.map { f in { f.matches($0) } })
        grid.onDone = { [weak self] ids in self?.finish(ids) }
        grid.onCancel = { [weak self] in self?.finish([]) }
        self.grid = grid
        nav.viewControllers = [grid]
        addChild(nav)
        nav.view.frame = view.bounds
        nav.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(nav.view)
        nav.didMove(toParent: self)
    }
    weak var grid: _ISIMPhotoGridController?
    /// Changes the shown picker: its selection limit (the selection is trimmed to it) and margins.
    public func updatePicker(using configuration: PHPickerConfiguration.Update) {
        guard let limit = configuration.selectionLimit, let grid else { return }
        grid.limit = limit
        if limit > 0, grid.selected.count > limit { grid.selected = Array(grid.selected.prefix(limit)) }
        grid.title = limit == 1 ? "Photos" : "Select Items"
    }
    func finish(_ ids: [String]) {
        guard !finished else { return }
        finished = true
        let all = Dictionary(uniqueKeysWithValues: PHAsset._isimAll().map { ($0.localIdentifier, $0) })
        let results = ids.compactMap { all[$0] }.filter { configuration.filter?.matches($0) ?? true }
            .map { PHPickerResult(itemProvider: _PUAssets.provider($0), assetIdentifier: configuration.identifiers ? $0.localIdentifier : nil) }
        NSLog("isim PhotosUI: picked %d item(s)", results.count)
        if let delegate { delegate.picker(self, didFinishPicking: results) }
        else if let d = _objcDelegate { d.picker(self, didFinishPicking: results.compactMap(_PUObjC.result)) }
        else { presentingViewController?.dismiss(animated: true, completion: nil) }
    }
    @objc open func deselectAssets(withIdentifiers identifiers: [String]) {}
    @objc open func moveAsset(withIdentifier identifier: String, afterAssetWithIdentifier: String?) {}
    @objc open func scrollToInitialPosition() {}
}

// MARK: - SwiftUI

public struct PhotosPickerItem: Equatable, Hashable, Sendable {
    public enum EncodingDisambiguationPolicy: Equatable, Hashable, Sendable { case automatic, current, compatible }
    public let itemIdentifier: String?
    let assetID: String
    let path: String
    public var supportedContentTypes: [UTType] { [UTType(_PUAssets.type(path)) ?? .jpeg] }
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

// MARK: - Live Photos from item providers

extension PHLivePhoto: @retroactive NSItemProviderReading {
    static let _bundleType = "com.apple.live-photo-bundle"
    static func _isimOf(_ asset: PHAsset) -> PHLivePhoto? { PHLivePhoto._isimLivePhoto(of: asset) }
    public static var readableTypeIdentifiersForItemProvider: [String] { [_bundleType] }
    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        guard let l = try NSKeyedUnarchiver.unarchivedObject(ofClass: PHLivePhoto.self, from: data) as? Self else {
            throw NSError(domain: NSItemProviderErrorDomain, code: -1200, userInfo: nil)   // NSItemProviderUnavailableCoercionError
        }
        return l
    }
}
