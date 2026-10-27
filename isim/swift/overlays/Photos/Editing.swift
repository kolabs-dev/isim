// isim Photos: edits (issue #372). PHAsset.requestContentEditingInput hands an app the asset's full-size image (or
// movie) and, when the app can read them, the adjustments of an earlier edit with the original instead;
// PHContentEditingOutput takes the rendered result and the app's PHAdjustmentData, and a change request
// (contentEditingOutput) stores them beside the original, which revertAssetContentToOriginal restores. Image requests
// with version .original / .unadjusted read the original. Adapted: no editing extensions or iCloud.
import UIKit
import AVFoundation
import CoreLocation
import UniformTypeIdentifiers

public typealias PHContentEditingInputRequestID = UInt
public let PHContentEditingInputResultIsInCloudKey = "PHContentEditingInputResultIsInCloudKey"
public let PHContentEditingInputCancelledKey = "PHContentEditingInputCancelledKey"
public let PHContentEditingInputErrorKey = "PHContentEditingInputErrorKey"

extension PHAsset {
    /// How the asset plays.
    @objc(PHAssetPlaybackStyle) public enum PlaybackStyle: Int, Sendable {
        case unsupported = 0, image = 1, imageAnimated = 2, livePhoto = 3, video = 4, videoLooping = 5
    }
    /// Which resource editing starts from.
    @objc(PHAssetOriginalResourceChoice) public enum OriginalResourceChoice: Int, Sendable {
        case defaultResource = 0, alternateResource = 1
    }
}

/// An app's description of an edit, stored with the edited asset so the app can change it later.
@objc(PHAdjustmentData) open class PHAdjustmentData: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc open var formatIdentifier: String
    @objc open var formatVersion: String
    @objc open var data: Data
    @objc public init(formatIdentifier: String, formatVersion: String, data: Data) {
        self.formatIdentifier = formatIdentifier; self.formatVersion = formatVersion; self.data = data
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) {
        coder.encode(formatIdentifier, forKey: "formatIdentifier"); coder.encode(formatVersion, forKey: "formatVersion")
        coder.encode(data as NSData, forKey: "data")
    }
    @objc public required init?(coder: NSCoder) {
        guard let f = coder.decodeObject(of: NSString.self, forKey: "formatIdentifier") as String?,
              let v = coder.decodeObject(of: NSString.self, forKey: "formatVersion") as String?,
              let d = coder.decodeObject(of: NSData.self, forKey: "data") as Data? else { return nil }
        formatIdentifier = f; formatVersion = v; data = d
        super.init()
    }
    var _plist: [String: Any] { ["formatIdentifier": formatIdentifier, "formatVersion": formatVersion, "data": data] }
    convenience init?(_plist p: [String: Any]) {
        guard let f = p["formatIdentifier"] as? String, let v = p["formatVersion"] as? String, let d = p["data"] as? Data else { return nil }
        self.init(formatIdentifier: f, formatVersion: v, data: d)
    }
}

@objc(PHContentEditingInputRequestOptions) open class PHContentEditingInputRequestOptions: NSObject, @unchecked Sendable {
    /// Whether the app can apply an earlier edit's adjustments to the original (then it gets the original and them).
    @objc open var canHandleAdjustmentData: (PHAdjustmentData) -> Bool = { _ in false }
    @nonobjc open var originalResourceChoice: PHAsset.OriginalResourceChoice = .defaultResource
    @objc(originalResourceChoice) var _objcOriginalResourceChoice: Int {
        get { originalResourceChoice.rawValue }
        set { originalResourceChoice = PHAsset.OriginalResourceChoice(rawValue: newValue) ?? .defaultResource }
    }
    @objc open var skipsDisplaySizeImage = false
    @nonobjc open var isNetworkAccessAllowed = false
    @objc(isNetworkAccessAllowed) var _objcNetworkAccessAllowed: Bool {
        get { isNetworkAccessAllowed }
        @objc(setNetworkAccessAllowed:) set { isNetworkAccessAllowed = newValue }
    }
    @objc open var progressHandler: ((Double, UnsafeMutablePointer<ObjCBool>) -> Void)?
    @objc public override init() { super.init() }
}

/// What an app edits: the asset's image or movie, and an earlier edit's adjustments when the app handles them.
@objc(PHContentEditingInput) open class PHContentEditingInput: NSObject, @unchecked Sendable {
    let rec: _PHRecord
    let fromOriginal: Bool
    init(_ rec: _PHRecord, fromOriginal: Bool, adjustment: PHAdjustmentData?, displaySize: Bool) {
        self.rec = rec; self.fromOriginal = fromOriginal; adjustmentData = adjustment
        let path = fromOriginal ? _PHStore.originalPath(rec) : _PHStore.imagePath(rec)
        if displaySize, let img = UIImage(contentsOfFile: path) {
            // a screen-sized copy, as iOS hands out
            let s = min(1, 1200 / max(img.size.width, img.size.height, 1))
            if s < 1 {
                let size = CGSize(width: (img.size.width * s).rounded(), height: (img.size.height * s).rounded())
                let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
                displaySizeImage = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
            } else { displaySizeImage = img }
        } else { displaySizeImage = nil }
        super.init()
    }
    @objc open var mediaType: PHAssetMediaType { rec.isVideo ? .video : .image }
    open var mediaSubtypes: PHAssetMediaSubtype { PHAsset(rec).mediaSubtypes }
    @objc(mediaSubtypes) var _objcMediaSubtypes: UInt { mediaSubtypes.rawValue }
    @objc open var creationDate: Date? { Date(timeIntervalSince1970: rec.created) }
    @objc open var location: CLLocation? { nil }
    /// the type of the full-size file
    @objc open var uniformTypeIdentifier: String? { contentType?.identifier }
    open var contentType: UTType? {
        let ext = ((fromOriginal ? rec.originalFile : rec.file) as NSString).pathExtension
        return UTType(filenameExtension: ext.lowercased())
    }
    @nonobjc open var playbackStyle: PHAsset.PlaybackStyle { PHAsset(rec).playbackStyle }
    @objc(playbackStyle) var _objcPlaybackStyle: Int { playbackStyle.rawValue }
    @objc public let adjustmentData: PHAdjustmentData?
    @objc public let displaySizeImage: UIImage?
    /// the image to edit (nil for a video)
    @objc open var fullSizeImageURL: URL? {
        rec.isVideo ? nil : URL(fileURLWithPath: fromOriginal ? _PHStore.originalPath(rec) : _PHStore.path(rec))
    }
    @objc open var fullSizeImageOrientation: Int32 { 1 }
    /// the movie to edit (nil for a photo)
    @objc open var audiovisualAsset: AVAsset? {
        rec.isVideo ? AVURLAsset(url: URL(fileURLWithPath: fromOriginal ? _PHStore.originalPath(rec) : _PHStore.path(rec))) : nil
    }
    @available(iOS, deprecated: 9.0, renamed: "audiovisualAsset")
    @objc open var avAsset: AVAsset? { audiovisualAsset }
    /// the Live Photo to edit, for a Live Photo
    @objc open var livePhoto: PHLivePhoto? { PHLivePhoto(record: rec) }
}

/// Where an app puts an edit: the rendered image or movie, with the adjustments that describe it.
@objc(PHContentEditingOutput) open class PHContentEditingOutput: NSObject, NSSecureCoding, @unchecked Sendable {
    let isVideo: Bool
    let assetID: String
    let dir: URL
    @objc open var adjustmentData: PHAdjustmentData?
    @objc public init(contentEditingInput: PHContentEditingInput) {
        isVideo = contentEditingInput.rec.isVideo; assetID = contentEditingInput.rec.id
        dir = Self.makeDir()
        super.init()
    }
    @objc public init(placeholderForCreatedAsset placeholder: PHObjectPlaceholder) {
        isVideo = false; assetID = placeholder.localIdentifier
        dir = Self.makeDir()
        super.init()
    }
    static func makeDir() -> URL {
        let d = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PHContentEditingOutput-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    /// The file the app writes the rendered result to: a JPEG for photos, a QuickTime movie for videos.
    @objc open var renderedContentURL: URL { dir.appendingPathComponent(isVideo ? "FullSizeRender.mov" : "FullSizeRender.jpg") }
    open var defaultRenderedContentType: UTType? { isVideo ? .quickTimeMovie : .jpeg }
    open var supportedRenderedContentTypes: [UTType] { isVideo ? [.quickTimeMovie] : [.jpeg, .png] }
    open func renderedContentURL(for type: UTType) throws -> URL {
        guard supportedRenderedContentTypes.contains(type), let ext = type.preferredFilenameExtension else {
            throw PHPhotosError(.invalidResource)
        }
        return dir.appendingPathComponent("FullSizeRender.\(ext)")
    }
    /// the rendered file the app wrote, if any
    var _rendered: URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.first { $0.hasPrefix("FullSizeRender.") }.map { dir.appendingPathComponent($0) }
    }

    public static var supportsSecureCoding: Bool { true }
    @objc public func encode(with coder: NSCoder) {
        coder.encode(isVideo, forKey: "isVideo"); coder.encode(assetID, forKey: "asset"); coder.encode(dir.path, forKey: "dir")
        coder.encode(adjustmentData, forKey: "adjustmentData")
    }
    @objc public required init?(coder: NSCoder) {
        guard let a = coder.decodeObject(of: NSString.self, forKey: "asset") as String?,
              let d = coder.decodeObject(of: NSString.self, forKey: "dir") as String? else { return nil }
        isVideo = coder.decodeBool(forKey: "isVideo"); assetID = a; dir = URL(fileURLWithPath: d)
        adjustmentData = coder.decodeObject(of: PHAdjustmentData.self, forKey: "adjustmentData")
        super.init()
    }
}

extension PHAsset {
    @nonobjc nonisolated(unsafe) static var _editingNextID: PHContentEditingInputRequestID = 1
    @nonobjc nonisolated(unsafe) static var _editingCancelled = Set<PHContentEditingInputRequestID>()

    /// Whether the asset carries an edit.
    @objc public var hasAdjustments: Bool { !rec.originalFile.isEmpty }
    @nonobjc public var playbackStyle: PlaybackStyle {
        if rec.isVideo { return .video }
        if !rec.live.isEmpty { return .livePhoto }
        return rec.file.lowercased().hasSuffix(".gif") ? .imageAnimated : .image
    }
    @objc(playbackStyle) var _objcPlaybackStyle: Int { playbackStyle.rawValue }

    /// The input for an edit, on the main queue: the asset as it is, or (when the options' canHandleAdjustmentData
    /// accepts the stored adjustments) the original with them.
    @discardableResult
    @objc(requestContentEditingInputWithOptions:completionHandler:)
    public func requestContentEditingInput(with options: PHContentEditingInputRequestOptions?,
                                         completionHandler: @escaping (PHContentEditingInput?, [AnyHashable: Any]) -> Void) -> PHContentEditingInputRequestID {
        let id = Self._editingNextID; Self._editingNextID += 1
        let rec = _PHStore.records().first { $0.id == localIdentifier } ?? self.rec
        DispatchQueue.main.async {
            if Self._editingCancelled.contains(id) { completionHandler(nil, [PHContentEditingInputCancelledKey: true]); return }
            guard _PHAuth.status == .authorized || _PHAuth.status == .limited else {
                completionHandler(nil, [PHContentEditingInputErrorKey: PHPhotosError(.accessUserDenied)]); return
            }
            if let progress = options?.progressHandler { var stop = ObjCBool(false); progress(1, &stop) }
            let stored = _PHStore.adjustment(rec)
            let handles = stored.map { options?.canHandleAdjustmentData($0) ?? false } ?? false
            let input = PHContentEditingInput(rec, fromOriginal: handles, adjustment: handles ? stored : nil,
                                              displaySize: !(options?.skipsDisplaySizeImage ?? false))
            completionHandler(input, [PHContentEditingInputResultIsInCloudKey: false])
        }
        return id
    }
    @objc public func cancelContentEditingInputRequest(_ requestID: PHContentEditingInputRequestID) { Self._editingCancelled.insert(requestID) }
}

extension _PHStore {
    /// the original file of an edited asset (its current file when unedited)
    static func originalPath(_ r: _PHRecord) -> String {
        (media as NSString).appendingPathComponent(r.originalFile.isEmpty ? r.file : r.originalFile)
    }
    static func adjustment(_ r: _PHRecord) -> PHAdjustmentData? {
        guard !r.adjustment.isEmpty, let d = FileManager.default.contents(atPath: (media as NSString).appendingPathComponent(r.adjustment)),
              let p = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: Any] else { return nil }
        return PHAdjustmentData(_plist: p)
    }
    /// stores an edit of an asset: the rendered file beside the original, and the adjustments
    static func applyEdit(_ id: String, _ output: PHContentEditingOutput) throws {
        guard let rendered = output._rendered, let adjustment = output.adjustmentData else { throw PHPhotosError(.invalidResource) }
        guard let rec = records().first(where: { $0.id == id }) else { throw PHPhotosError(.invalidResource) }
        let base = ((rec.originalFile.isEmpty ? rec.file : rec.originalFile) as NSString).deletingPathExtension
        let edited = "\(base)_E.\(rendered.pathExtension.uppercased())"
        let adjust = "PhotoData/Adjustments/\((base as NSString).lastPathComponent).plist"
        let fm = FileManager.default
        let editedPath = (media as NSString).appendingPathComponent(edited)
        try? fm.removeItem(atPath: editedPath)
        try fm.copyItem(atPath: rendered.path, toPath: editedPath)
        _ = _Privacy.deviceDir("Media/PhotoData/Adjustments")
        let plist = try PropertyListSerialization.data(fromPropertyList: adjustment._plist, format: .xml, options: 0)
        fm.createFile(atPath: (media as NSString).appendingPathComponent(adjust), contents: plist, attributes: nil)
        let size = UIImage(contentsOfFile: editedPath)?.cgImage.map { ($0.width, $0.height) }
        update { recs in
            guard let i = recs.firstIndex(where: { $0.id == id }) else { return }
            if recs[i].originalFile.isEmpty { recs[i].originalFile = recs[i].file }
            else if recs[i].file != recs[i].originalFile, recs[i].file != edited { try? fm.removeItem(atPath: path(recs[i])) }
            recs[i].file = edited
            recs[i].adjustment = adjust
            if let (w, h) = size { recs[i].width = w; recs[i].height = h }
            recs[i].modified = Date().timeIntervalSince1970
        }
    }
    /// drops an asset's edit
    static func revert(_ id: String) {
        update { recs in
            guard let i = recs.firstIndex(where: { $0.id == id }), !recs[i].originalFile.isEmpty else { return }
            try? FileManager.default.removeItem(atPath: path(recs[i]))
            try? FileManager.default.removeItem(atPath: (media as NSString).appendingPathComponent(recs[i].adjustment))
            recs[i].file = recs[i].originalFile
            recs[i].originalFile = ""; recs[i].adjustment = ""
            if let cg = UIImage(contentsOfFile: path(recs[i]))?.cgImage { recs[i].width = cg.width; recs[i].height = cg.height }
            recs[i].modified = Date().timeIntervalSince1970
        }
    }
}
