// isim QuickLookThumbnailing Swift overlay (issue #359): the API that takes UTType (the Objective-C UTType class is
// the UniformTypeIdentifiers overlay's in Swift): a request's content type and saving as a content type.
@_exported import QuickLookThumbnailing
import UniformTypeIdentifiers

/// QuickLookThumbnailing's errors (NSErrors of QLThumbnailErrorDomain bridge to it).
@available(iOS 13.0, *)
public struct QLThumbnailError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case generationFailed = 0, savingToURLFailed, noCachedThumbnail, noCloudThumbnail, requestInvalid, requestCancelled
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { QLThumbnailErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var generationFailed: Code { .generationFailed }
    public static var savingToURLFailed: Code { .savingToURLFailed }
    public static var noCachedThumbnail: Code { .noCachedThumbnail }
    public static var noCloudThumbnail: Code { .noCloudThumbnail }
    public static var requestInvalid: Code { .requestInvalid }
    public static var requestCancelled: Code { .requestCancelled }
}
@available(iOS 13.0, *)
extension QLThumbnailError: _ObjectiveCBridgeableError {
    public init?(_bridgedNSError error: NSError) {
        guard error.domain == QLThumbnailErrorDomain, let code = Code(rawValue: error.code) else { return nil }
        self.init(code)
    }
}

extension QLThumbnailGenerator.Request {
    /// The file's content type: set, or the file's (by its filename extension).
    @available(iOS 16.0, *)
    public var contentType: UTType! {
        get {
            if let id = _isimContentTypeIdentifier, let t = UTType(id) { return t }
            return UTType(filenameExtension: _isimFileURL.pathExtension) ?? .data
        }
        set { _isimContentTypeIdentifier = newValue?.identifier }
    }
}

extension QLThumbnailGenerator {
    /// Saves the best representation as an image file of the content type (PNG, JPEG or HEIC).
    @available(iOS 14.0, *)
    public func saveBestRepresentation(for request: QLThumbnailGenerator.Request, to fileURL: URL, as contentType: UTType,
                                       completion: @escaping ((any Error)?) -> Void) {
        saveBestRepresentation(for: request, to: fileURL, contentType: contentType.identifier, completion: completion)
    }
}
