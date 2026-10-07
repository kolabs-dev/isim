// CocoaError: the Swift face of NSCocoaErrorDomain errors (`catch let e as CocoaError`, `CocoaError(.fileNoSuchFile)`).
// isim keeps the code and userInfo; an NSError of the Cocoa domain bridges to it through _ObjectiveCBridgeableError.

public struct CocoaError: Error, CustomNSError, LocalizedError, Hashable, _ObjectiveCBridgeableError, @unchecked Sendable {
    public struct Code: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let fileNoSuchFile = Code(rawValue: 4)
        public static let fileLocking = Code(rawValue: 255)
        public static let fileReadUnknown = Code(rawValue: 256)
        public static let fileReadNoPermission = Code(rawValue: 257)
        public static let fileReadInvalidFileName = Code(rawValue: 258)
        public static let fileReadCorruptFile = Code(rawValue: 259)
        public static let fileReadNoSuchFile = Code(rawValue: 260)
        public static let fileReadInapplicableStringEncoding = Code(rawValue: 261)
        public static let fileReadUnsupportedScheme = Code(rawValue: 262)
        public static let fileReadTooLarge = Code(rawValue: 263)
        public static let fileReadUnknownStringEncoding = Code(rawValue: 264)
        public static let fileWriteUnknown = Code(rawValue: 512)
        public static let fileWriteNoPermission = Code(rawValue: 513)
        public static let fileWriteInvalidFileName = Code(rawValue: 514)
        public static let fileWriteFileExists = Code(rawValue: 516)
        public static let fileWriteInapplicableStringEncoding = Code(rawValue: 517)
        public static let fileWriteUnsupportedScheme = Code(rawValue: 518)
        public static let fileWriteOutOfSpace = Code(rawValue: 640)
        public static let fileWriteVolumeReadOnly = Code(rawValue: 642)
        public static let keyValueValidation = Code(rawValue: 1024)
        public static let formatting = Code(rawValue: 2048)
        public static let userCancelled = Code(rawValue: 3072)
        public static let featureUnsupported = Code(rawValue: 3328)
        public static let propertyListReadCorrupt = Code(rawValue: 3840)
        public static let propertyListReadUnknownVersion = Code(rawValue: 3841)
        public static let propertyListReadStream = Code(rawValue: 3842)
        public static let propertyListWriteStream = Code(rawValue: 3851)
        public static let propertyListWriteInvalid = Code(rawValue: 3852)
        public static let coderReadCorrupt = Code(rawValue: 4864)
        public static let coderValueNotFound = Code(rawValue: 4865)
        public static let coderInvalidValue = Code(rawValue: 4866)
        public static let executableNotLoadable = Code(rawValue: 3584)
        public static let ubiquitousFileUnavailable = Code(rawValue: 4353)
    }
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; errorUserInfo = userInfo }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == NSCocoaErrorDomain else { return nil }
        self.init(Code(rawValue: e.code), userInfo: e.userInfo)
    }
    public static var errorDomain: String { NSCocoaErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var userInfo: [String: Any] { errorUserInfo }
    public var errorDescription: String? { errorUserInfo[NSLocalizedDescriptionKey] as? String }
    public var failureReason: String? { errorUserInfo[NSLocalizedFailureReasonErrorKey] as? String }
    public var filePath: String? { errorUserInfo[NSFilePathErrorKey] as? String }
    public var url: URL? { errorUserInfo[NSURLErrorKey] as? URL }
    public var underlying: Error? { errorUserInfo[NSUnderlyingErrorKey] as? Error }
    public var stringEncoding: String.Encoding? { (errorUserInfo[NSStringEncodingErrorKey] as? UInt).map { String.Encoding(rawValue: $0) } }
    public var isFileError: Bool { (0..<1024).contains(code.rawValue) }
    public var isCoderError: Bool { (4864...4991).contains(code.rawValue) }
    public var isPropertyListError: Bool { (3840...4095).contains(code.rawValue) }
    public var isFormattingError: Bool { (2048...2559).contains(code.rawValue) }
    public var isValidationError: Bool { (1024...2047).contains(code.rawValue) }
    public static func error(_ code: Code, userInfo: [AnyHashable: Any]? = nil, url: URL? = nil) -> Error {
        var info: [String: Any] = [:]
        for (k, v) in userInfo ?? [:] { if let k = k as? String { info[k] = v } }
        if let url { info[NSURLErrorKey] = url }
        return CocoaError(code, userInfo: info)
    }
    public static func == (a: CocoaError, b: CocoaError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
}
extension CocoaError.Code {
    /// `catch CocoaError.fileNoSuchFile`
    public static func ~= (match: CocoaError.Code, error: Error) -> Bool { (error as? CocoaError)?.code == match }
}
extension CocoaError {
    public static var fileNoSuchFile: CocoaError.Code { .fileNoSuchFile }
    public static var fileLocking: CocoaError.Code { .fileLocking }
    public static var fileReadUnknown: CocoaError.Code { .fileReadUnknown }
    public static var fileReadNoPermission: CocoaError.Code { .fileReadNoPermission }
    public static var fileReadInvalidFileName: CocoaError.Code { .fileReadInvalidFileName }
    public static var fileReadCorruptFile: CocoaError.Code { .fileReadCorruptFile }
    public static var fileReadNoSuchFile: CocoaError.Code { .fileReadNoSuchFile }
    public static var fileReadInapplicableStringEncoding: CocoaError.Code { .fileReadInapplicableStringEncoding }
    public static var fileReadUnsupportedScheme: CocoaError.Code { .fileReadUnsupportedScheme }
    public static var fileReadTooLarge: CocoaError.Code { .fileReadTooLarge }
    public static var fileReadUnknownStringEncoding: CocoaError.Code { .fileReadUnknownStringEncoding }
    public static var fileWriteUnknown: CocoaError.Code { .fileWriteUnknown }
    public static var fileWriteNoPermission: CocoaError.Code { .fileWriteNoPermission }
    public static var fileWriteInvalidFileName: CocoaError.Code { .fileWriteInvalidFileName }
    public static var fileWriteFileExists: CocoaError.Code { .fileWriteFileExists }
    public static var fileWriteInapplicableStringEncoding: CocoaError.Code { .fileWriteInapplicableStringEncoding }
    public static var fileWriteUnsupportedScheme: CocoaError.Code { .fileWriteUnsupportedScheme }
    public static var fileWriteOutOfSpace: CocoaError.Code { .fileWriteOutOfSpace }
    public static var fileWriteVolumeReadOnly: CocoaError.Code { .fileWriteVolumeReadOnly }
    public static var keyValueValidation: CocoaError.Code { .keyValueValidation }
    public static var formatting: CocoaError.Code { .formatting }
    public static var userCancelled: CocoaError.Code { .userCancelled }
    public static var featureUnsupported: CocoaError.Code { .featureUnsupported }
    public static var propertyListReadCorrupt: CocoaError.Code { .propertyListReadCorrupt }
    public static var propertyListReadUnknownVersion: CocoaError.Code { .propertyListReadUnknownVersion }
    public static var propertyListReadStream: CocoaError.Code { .propertyListReadStream }
    public static var propertyListWriteStream: CocoaError.Code { .propertyListWriteStream }
    public static var propertyListWriteInvalid: CocoaError.Code { .propertyListWriteInvalid }
    public static var coderReadCorrupt: CocoaError.Code { .coderReadCorrupt }
    public static var coderValueNotFound: CocoaError.Code { .coderValueNotFound }
    public static var coderInvalidValue: CocoaError.Code { .coderInvalidValue }
    public static var executableNotLoadable: CocoaError.Code { .executableNotLoadable }
    public static var ubiquitousFileUnavailable: CocoaError.Code { .ubiquitousFileUnavailable }
}

extension URLError: _ObjectiveCBridgeableError {
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == NSURLErrorDomain else { return nil }
        self.init(Code(rawValue: e.code), userInfo: e.userInfo)
    }
}
