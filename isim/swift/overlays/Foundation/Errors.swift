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
        public static let executableArchitectureMismatch = Code(rawValue: 3585)
        public static let executableRuntimeMismatch = Code(rawValue: 3586)
        public static let executableLoad = Code(rawValue: 3587)
        public static let executableLink = Code(rawValue: 3588)
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

/// The `NSError **` out-parameter of Objective-C methods, as Swift sees it.
public typealias NSErrorPointer = AutoreleasingUnsafeMutablePointer<NSError?>?

extension XMLParser {
    /// The domain of the errors XMLParser reports (`parserError`): NSXMLParserErrorDomain.
    public static let errorDomain: String = NSXMLParserErrorDomain
}

// MARK: - the codes isim lacked (issue #860): Apple's raw values (FoundationErrors.h, CoreDataErrors.h)
extension CocoaError.Code {
    public static var ubiquitousFileNotUploadedDueToQuota: CocoaError.Code { CocoaError.Code(rawValue: 4354) }
    public static var ubiquitousFileUbiquityServerNotAvailable: CocoaError.Code { CocoaError.Code(rawValue: 4355) }
    public static var userActivityHandoffFailed: CocoaError.Code { CocoaError.Code(rawValue: 4608) }
    public static var userActivityConnectionUnavailable: CocoaError.Code { CocoaError.Code(rawValue: 4609) }
    public static var userActivityRemoteApplicationTimedOut: CocoaError.Code { CocoaError.Code(rawValue: 4610) }
    public static var userActivityHandoffUserInfoTooLarge: CocoaError.Code { CocoaError.Code(rawValue: 4611) }
    public static var xpcConnectionInterrupted: CocoaError.Code { CocoaError.Code(rawValue: 4097) }
    public static var xpcConnectionInvalid: CocoaError.Code { CocoaError.Code(rawValue: 4099) }
    public static var xpcConnectionReplyInvalid: CocoaError.Code { CocoaError.Code(rawValue: 4101) }
    public static var managedObjectValidation: CocoaError.Code { CocoaError.Code(rawValue: 1550) }
    public static var validationMultipleErrors: CocoaError.Code { CocoaError.Code(rawValue: 1560) }
    public static var validationMissingMandatoryProperty: CocoaError.Code { CocoaError.Code(rawValue: 1570) }
    public static var validationRelationshipLacksMinimumCount: CocoaError.Code { CocoaError.Code(rawValue: 1580) }
    public static var validationRelationshipExceedsMaximumCount: CocoaError.Code { CocoaError.Code(rawValue: 1590) }
    public static var validationRelationshipDeniedDelete: CocoaError.Code { CocoaError.Code(rawValue: 1600) }
    public static var validationNumberTooLarge: CocoaError.Code { CocoaError.Code(rawValue: 1610) }
    public static var validationNumberTooSmall: CocoaError.Code { CocoaError.Code(rawValue: 1620) }
    public static var validationDateTooLate: CocoaError.Code { CocoaError.Code(rawValue: 1630) }
    public static var validationDateTooSoon: CocoaError.Code { CocoaError.Code(rawValue: 1640) }
    public static var validationInvalidDate: CocoaError.Code { CocoaError.Code(rawValue: 1650) }
    public static var validationStringTooLong: CocoaError.Code { CocoaError.Code(rawValue: 1660) }
    public static var validationStringTooShort: CocoaError.Code { CocoaError.Code(rawValue: 1670) }
    public static var validationStringPatternMatching: CocoaError.Code { CocoaError.Code(rawValue: 1680) }
    public static var managedObjectContextLocking: CocoaError.Code { CocoaError.Code(rawValue: 132000) }
    public static var persistentStoreCoordinatorLocking: CocoaError.Code { CocoaError.Code(rawValue: 132010) }
    public static var managedObjectReferentialIntegrity: CocoaError.Code { CocoaError.Code(rawValue: 133000) }
    public static var managedObjectExternalRelationship: CocoaError.Code { CocoaError.Code(rawValue: 133010) }
    public static var managedObjectMerge: CocoaError.Code { CocoaError.Code(rawValue: 133020) }
    public static var managedObjectConstraintMerge: CocoaError.Code { CocoaError.Code(rawValue: 133021) }
    public static var persistentStoreInvalidType: CocoaError.Code { CocoaError.Code(rawValue: 134000) }
    public static var persistentStoreTypeMismatch: CocoaError.Code { CocoaError.Code(rawValue: 134010) }
    public static var persistentStoreIncompatibleSchema: CocoaError.Code { CocoaError.Code(rawValue: 134020) }
    public static var persistentStoreSave: CocoaError.Code { CocoaError.Code(rawValue: 134030) }
    public static var persistentStoreIncompleteSave: CocoaError.Code { CocoaError.Code(rawValue: 134040) }
    public static var persistentStoreSaveConflicts: CocoaError.Code { CocoaError.Code(rawValue: 134050) }
    public static var coreData: CocoaError.Code { CocoaError.Code(rawValue: 134060) }
    public static var persistentStoreOperation: CocoaError.Code { CocoaError.Code(rawValue: 134070) }
    public static var persistentStoreOpen: CocoaError.Code { CocoaError.Code(rawValue: 134080) }
    public static var persistentStoreTimeout: CocoaError.Code { CocoaError.Code(rawValue: 134090) }
    public static var persistentStoreUnsupportedRequestType: CocoaError.Code { CocoaError.Code(rawValue: 134091) }
    public static var persistentStoreIncompatibleVersionHash: CocoaError.Code { CocoaError.Code(rawValue: 134100) }
    public static var migration: CocoaError.Code { CocoaError.Code(rawValue: 134110) }
    public static var migrationCancelled: CocoaError.Code { CocoaError.Code(rawValue: 134120) }
    public static var migrationMissingSourceModel: CocoaError.Code { CocoaError.Code(rawValue: 134130) }
    public static var migrationMissingMappingModel: CocoaError.Code { CocoaError.Code(rawValue: 134140) }
    public static var migrationManagerSourceStore: CocoaError.Code { CocoaError.Code(rawValue: 134150) }
    public static var migrationManagerDestinationStore: CocoaError.Code { CocoaError.Code(rawValue: 134160) }
    public static var entityMigrationPolicy: CocoaError.Code { CocoaError.Code(rawValue: 134170) }
    public static var sqlite: CocoaError.Code { CocoaError.Code(rawValue: 134180) }
    public static var inferredMappingModel: CocoaError.Code { CocoaError.Code(rawValue: 134190) }
    public static var externalRecordImport: CocoaError.Code { CocoaError.Code(rawValue: 134200) }
    @available(swift, deprecated: 4.2, renamed: "fileNoSuchFile") public static var fileNoSuchFileError: CocoaError.Code { .fileNoSuchFile }
    @available(swift, deprecated: 4.2, renamed: "fileLocking") public static var fileLockingError: CocoaError.Code { .fileLocking }
    @available(swift, deprecated: 4.2, renamed: "fileReadUnknown") public static var fileReadUnknownError: CocoaError.Code { .fileReadUnknown }
    @available(swift, deprecated: 4.2, renamed: "fileReadNoPermission") public static var fileReadNoPermissionError: CocoaError.Code { .fileReadNoPermission }
    @available(swift, deprecated: 4.2, renamed: "fileReadInvalidFileName") public static var fileReadInvalidFileNameError: CocoaError.Code { .fileReadInvalidFileName }
    @available(swift, deprecated: 4.2, renamed: "fileReadCorruptFile") public static var fileReadCorruptFileError: CocoaError.Code { .fileReadCorruptFile }
    @available(swift, deprecated: 4.2, renamed: "fileReadNoSuchFile") public static var fileReadNoSuchFileError: CocoaError.Code { .fileReadNoSuchFile }
    @available(swift, deprecated: 4.2, renamed: "fileReadInapplicableStringEncoding") public static var fileReadInapplicableStringEncodingError: CocoaError.Code { .fileReadInapplicableStringEncoding }
    @available(swift, deprecated: 4.2, renamed: "fileReadUnsupportedScheme") public static var fileReadUnsupportedSchemeError: CocoaError.Code { .fileReadUnsupportedScheme }
    @available(swift, deprecated: 4.2, renamed: "fileReadTooLarge") public static var fileReadTooLargeError: CocoaError.Code { .fileReadTooLarge }
    @available(swift, deprecated: 4.2, renamed: "fileReadUnknownStringEncoding") public static var fileReadUnknownStringEncodingError: CocoaError.Code { .fileReadUnknownStringEncoding }
    @available(swift, deprecated: 4.2, renamed: "fileWriteUnknown") public static var fileWriteUnknownError: CocoaError.Code { .fileWriteUnknown }
    @available(swift, deprecated: 4.2, renamed: "fileWriteNoPermission") public static var fileWriteNoPermissionError: CocoaError.Code { .fileWriteNoPermission }
    @available(swift, deprecated: 4.2, renamed: "fileWriteInvalidFileName") public static var fileWriteInvalidFileNameError: CocoaError.Code { .fileWriteInvalidFileName }
    @available(swift, deprecated: 4.2, renamed: "fileWriteFileExists") public static var fileWriteFileExistsError: CocoaError.Code { .fileWriteFileExists }
    @available(swift, deprecated: 4.2, renamed: "fileWriteInapplicableStringEncoding") public static var fileWriteInapplicableStringEncodingError: CocoaError.Code { .fileWriteInapplicableStringEncoding }
    @available(swift, deprecated: 4.2, renamed: "fileWriteUnsupportedScheme") public static var fileWriteUnsupportedSchemeError: CocoaError.Code { .fileWriteUnsupportedScheme }
    @available(swift, deprecated: 4.2, renamed: "fileWriteOutOfSpace") public static var fileWriteOutOfSpaceError: CocoaError.Code { .fileWriteOutOfSpace }
    @available(swift, deprecated: 4.2, renamed: "fileWriteVolumeReadOnly") public static var fileWriteVolumeReadOnlyError: CocoaError.Code { .fileWriteVolumeReadOnly }
    @available(swift, deprecated: 4.2, renamed: "keyValueValidation") public static var keyValueValidationError: CocoaError.Code { .keyValueValidation }
    @available(swift, deprecated: 4.2, renamed: "formatting") public static var formattingError: CocoaError.Code { .formatting }
    @available(swift, deprecated: 4.2, renamed: "userCancelled") public static var userCancelledError: CocoaError.Code { .userCancelled }
    @available(swift, deprecated: 4.2, renamed: "featureUnsupported") public static var featureUnsupportedError: CocoaError.Code { .featureUnsupported }
    @available(swift, deprecated: 4.2, renamed: "propertyListReadCorrupt") public static var propertyListReadCorruptError: CocoaError.Code { .propertyListReadCorrupt }
    @available(swift, deprecated: 4.2, renamed: "propertyListReadUnknownVersion") public static var propertyListReadUnknownVersionError: CocoaError.Code { .propertyListReadUnknownVersion }
    @available(swift, deprecated: 4.2, renamed: "propertyListReadStream") public static var propertyListReadStreamError: CocoaError.Code { .propertyListReadStream }
    @available(swift, deprecated: 4.2, renamed: "propertyListWriteStream") public static var propertyListWriteStreamError: CocoaError.Code { .propertyListWriteStream }
    @available(swift, deprecated: 4.2, renamed: "propertyListWriteInvalid") public static var propertyListWriteInvalidError: CocoaError.Code { .propertyListWriteInvalid }
    @available(swift, deprecated: 4.2, renamed: "coderReadCorrupt") public static var coderReadCorruptError: CocoaError.Code { .coderReadCorrupt }
    @available(swift, deprecated: 4.2, renamed: "coderValueNotFound") public static var coderValueNotFoundError: CocoaError.Code { .coderValueNotFound }
    @available(swift, deprecated: 4.2, renamed: "executableNotLoadable") public static var executableNotLoadableError: CocoaError.Code { .executableNotLoadable }
    @available(swift, deprecated: 4.2, renamed: "executableArchitectureMismatch") public static var executableArchitectureMismatchError: CocoaError.Code { .executableArchitectureMismatch }
    @available(swift, deprecated: 4.2, renamed: "executableRuntimeMismatch") public static var executableRuntimeMismatchError: CocoaError.Code { .executableRuntimeMismatch }
    @available(swift, deprecated: 4.2, renamed: "executableLoad") public static var executableLoadError: CocoaError.Code { .executableLoad }
    @available(swift, deprecated: 4.2, renamed: "executableLink") public static var executableLinkError: CocoaError.Code { .executableLink }
    @available(swift, deprecated: 4.2, renamed: "ubiquitousFileUnavailable") public static var ubiquitousFileUnavailableError: CocoaError.Code { .ubiquitousFileUnavailable }
    @available(swift, deprecated: 4.2, renamed: "ubiquitousFileNotUploadedDueToQuota") public static var ubiquitousFileNotUploadedDueToQuotaError: CocoaError.Code { .ubiquitousFileNotUploadedDueToQuota }
    @available(swift, deprecated: 4.2, renamed: "userActivityHandoffFailed") public static var userActivityHandoffFailedError: CocoaError.Code { .userActivityHandoffFailed }
    @available(swift, deprecated: 4.2, renamed: "userActivityConnectionUnavailable") public static var userActivityConnectionUnavailableError: CocoaError.Code { .userActivityConnectionUnavailable }
    @available(swift, deprecated: 4.2, renamed: "userActivityRemoteApplicationTimedOut") public static var userActivityRemoteApplicationTimedOutError: CocoaError.Code { .userActivityRemoteApplicationTimedOut }
    @available(swift, deprecated: 4.2, renamed: "userActivityHandoffUserInfoTooLarge") public static var userActivityHandoffUserInfoTooLargeError: CocoaError.Code { .userActivityHandoffUserInfoTooLarge }
    @available(swift, deprecated: 4.2, renamed: "managedObjectValidation") public static var managedObjectValidationError: CocoaError.Code { .managedObjectValidation }
    @available(swift, deprecated: 4.2, renamed: "validationMultipleErrors") public static var validationMultipleErrorsError: CocoaError.Code { .validationMultipleErrors }
    @available(swift, deprecated: 4.2, renamed: "validationMissingMandatoryProperty") public static var validationMissingMandatoryPropertyError: CocoaError.Code { .validationMissingMandatoryProperty }
    @available(swift, deprecated: 4.2, renamed: "validationRelationshipLacksMinimumCount") public static var validationRelationshipLacksMinimumCountError: CocoaError.Code { .validationRelationshipLacksMinimumCount }
    @available(swift, deprecated: 4.2, renamed: "validationRelationshipExceedsMaximumCount") public static var validationRelationshipExceedsMaximumCountError: CocoaError.Code { .validationRelationshipExceedsMaximumCount }
    @available(swift, deprecated: 4.2, renamed: "validationRelationshipDeniedDelete") public static var validationRelationshipDeniedDeleteError: CocoaError.Code { .validationRelationshipDeniedDelete }
    @available(swift, deprecated: 4.2, renamed: "validationNumberTooLarge") public static var validationNumberTooLargeError: CocoaError.Code { .validationNumberTooLarge }
    @available(swift, deprecated: 4.2, renamed: "validationNumberTooSmall") public static var validationNumberTooSmallError: CocoaError.Code { .validationNumberTooSmall }
    @available(swift, deprecated: 4.2, renamed: "validationDateTooLate") public static var validationDateTooLateError: CocoaError.Code { .validationDateTooLate }
    @available(swift, deprecated: 4.2, renamed: "validationDateTooSoon") public static var validationDateTooSoonError: CocoaError.Code { .validationDateTooSoon }
    @available(swift, deprecated: 4.2, renamed: "validationInvalidDate") public static var validationInvalidDateError: CocoaError.Code { .validationInvalidDate }
    @available(swift, deprecated: 4.2, renamed: "validationStringTooLong") public static var validationStringTooLongError: CocoaError.Code { .validationStringTooLong }
    @available(swift, deprecated: 4.2, renamed: "validationStringTooShort") public static var validationStringTooShortError: CocoaError.Code { .validationStringTooShort }
    @available(swift, deprecated: 4.2, renamed: "validationStringPatternMatching") public static var validationStringPatternMatchingError: CocoaError.Code { .validationStringPatternMatching }
    @available(swift, deprecated: 4.2, renamed: "managedObjectContextLocking") public static var managedObjectContextLockingError: CocoaError.Code { .managedObjectContextLocking }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreCoordinatorLocking") public static var persistentStoreCoordinatorLockingError: CocoaError.Code { .persistentStoreCoordinatorLocking }
    @available(swift, deprecated: 4.2, renamed: "managedObjectReferentialIntegrity") public static var managedObjectReferentialIntegrityError: CocoaError.Code { .managedObjectReferentialIntegrity }
    @available(swift, deprecated: 4.2, renamed: "managedObjectExternalRelationship") public static var managedObjectExternalRelationshipError: CocoaError.Code { .managedObjectExternalRelationship }
    @available(swift, deprecated: 4.2, renamed: "managedObjectMerge") public static var managedObjectMergeError: CocoaError.Code { .managedObjectMerge }
    @available(swift, deprecated: 4.2, renamed: "managedObjectConstraintMerge") public static var managedObjectConstraintMergeError: CocoaError.Code { .managedObjectConstraintMerge }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreInvalidType") public static var persistentStoreInvalidTypeError: CocoaError.Code { .persistentStoreInvalidType }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreTypeMismatch") public static var persistentStoreTypeMismatchError: CocoaError.Code { .persistentStoreTypeMismatch }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreIncompatibleSchema") public static var persistentStoreIncompatibleSchemaError: CocoaError.Code { .persistentStoreIncompatibleSchema }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreSave") public static var persistentStoreSaveError: CocoaError.Code { .persistentStoreSave }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreIncompleteSave") public static var persistentStoreIncompleteSaveError: CocoaError.Code { .persistentStoreIncompleteSave }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreSaveConflicts") public static var persistentStoreSaveConflictsError: CocoaError.Code { .persistentStoreSaveConflicts }
    @available(swift, deprecated: 4.2, renamed: "coreData") public static var coreDataError: CocoaError.Code { .coreData }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreOperation") public static var persistentStoreOperationError: CocoaError.Code { .persistentStoreOperation }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreOpen") public static var persistentStoreOpenError: CocoaError.Code { .persistentStoreOpen }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreTimeout") public static var persistentStoreTimeoutError: CocoaError.Code { .persistentStoreTimeout }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreUnsupportedRequestType") public static var persistentStoreUnsupportedRequestTypeError: CocoaError.Code { .persistentStoreUnsupportedRequestType }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreIncompatibleVersionHash") public static var persistentStoreIncompatibleVersionHashError: CocoaError.Code { .persistentStoreIncompatibleVersionHash }
    @available(swift, deprecated: 4.2, renamed: "migration") public static var migrationError: CocoaError.Code { .migration }
    @available(swift, deprecated: 4.2, renamed: "migrationCancelled") public static var migrationCancelledError: CocoaError.Code { .migrationCancelled }
    @available(swift, deprecated: 4.2, renamed: "migrationMissingSourceModel") public static var migrationMissingSourceModelError: CocoaError.Code { .migrationMissingSourceModel }
    @available(swift, deprecated: 4.2, renamed: "migrationMissingMappingModel") public static var migrationMissingMappingModelError: CocoaError.Code { .migrationMissingMappingModel }
    @available(swift, deprecated: 4.2, renamed: "migrationManagerSourceStore") public static var migrationManagerSourceStoreError: CocoaError.Code { .migrationManagerSourceStore }
    @available(swift, deprecated: 4.2, renamed: "migrationManagerDestinationStore") public static var migrationManagerDestinationStoreError: CocoaError.Code { .migrationManagerDestinationStore }
    @available(swift, deprecated: 4.2, renamed: "entityMigrationPolicy") public static var entityMigrationPolicyError: CocoaError.Code { .entityMigrationPolicy }
    @available(swift, deprecated: 4.2, renamed: "sqlite") public static var sqliteError: CocoaError.Code { .sqlite }
    @available(swift, deprecated: 4.2, renamed: "inferredMappingModel") public static var inferredMappingModelError: CocoaError.Code { .inferredMappingModel }
    @available(swift, deprecated: 4.2, renamed: "externalRecordImport") public static var externalRecordImportError: CocoaError.Code { .externalRecordImport }
}
extension CocoaError {
    public static var executableArchitectureMismatch: CocoaError.Code { .executableArchitectureMismatch }
    public static var executableRuntimeMismatch: CocoaError.Code { .executableRuntimeMismatch }
    public static var executableLoad: CocoaError.Code { .executableLoad }
    public static var executableLink: CocoaError.Code { .executableLink }
    public static var ubiquitousFileNotUploadedDueToQuota: CocoaError.Code { .ubiquitousFileNotUploadedDueToQuota }
    public static var ubiquitousFileUbiquityServerNotAvailable: CocoaError.Code { .ubiquitousFileUbiquityServerNotAvailable }
    public static var userActivityHandoffFailed: CocoaError.Code { .userActivityHandoffFailed }
    public static var userActivityConnectionUnavailable: CocoaError.Code { .userActivityConnectionUnavailable }
    public static var userActivityRemoteApplicationTimedOut: CocoaError.Code { .userActivityRemoteApplicationTimedOut }
    public static var userActivityHandoffUserInfoTooLarge: CocoaError.Code { .userActivityHandoffUserInfoTooLarge }
    public static var xpcConnectionInterrupted: CocoaError.Code { .xpcConnectionInterrupted }
    public static var xpcConnectionInvalid: CocoaError.Code { .xpcConnectionInvalid }
    public static var xpcConnectionReplyInvalid: CocoaError.Code { .xpcConnectionReplyInvalid }
    public static var managedObjectValidation: CocoaError.Code { .managedObjectValidation }
    public static var validationMultipleErrors: CocoaError.Code { .validationMultipleErrors }
    public static var validationMissingMandatoryProperty: CocoaError.Code { .validationMissingMandatoryProperty }
    public static var validationRelationshipLacksMinimumCount: CocoaError.Code { .validationRelationshipLacksMinimumCount }
    public static var validationRelationshipExceedsMaximumCount: CocoaError.Code { .validationRelationshipExceedsMaximumCount }
    public static var validationRelationshipDeniedDelete: CocoaError.Code { .validationRelationshipDeniedDelete }
    public static var validationNumberTooLarge: CocoaError.Code { .validationNumberTooLarge }
    public static var validationNumberTooSmall: CocoaError.Code { .validationNumberTooSmall }
    public static var validationDateTooLate: CocoaError.Code { .validationDateTooLate }
    public static var validationDateTooSoon: CocoaError.Code { .validationDateTooSoon }
    public static var validationInvalidDate: CocoaError.Code { .validationInvalidDate }
    public static var validationStringTooLong: CocoaError.Code { .validationStringTooLong }
    public static var validationStringTooShort: CocoaError.Code { .validationStringTooShort }
    public static var validationStringPatternMatching: CocoaError.Code { .validationStringPatternMatching }
    public static var managedObjectContextLocking: CocoaError.Code { .managedObjectContextLocking }
    public static var persistentStoreCoordinatorLocking: CocoaError.Code { .persistentStoreCoordinatorLocking }
    public static var managedObjectReferentialIntegrity: CocoaError.Code { .managedObjectReferentialIntegrity }
    public static var managedObjectExternalRelationship: CocoaError.Code { .managedObjectExternalRelationship }
    public static var managedObjectMerge: CocoaError.Code { .managedObjectMerge }
    public static var managedObjectConstraintMerge: CocoaError.Code { .managedObjectConstraintMerge }
    public static var persistentStoreInvalidType: CocoaError.Code { .persistentStoreInvalidType }
    public static var persistentStoreTypeMismatch: CocoaError.Code { .persistentStoreTypeMismatch }
    public static var persistentStoreIncompatibleSchema: CocoaError.Code { .persistentStoreIncompatibleSchema }
    public static var persistentStoreSave: CocoaError.Code { .persistentStoreSave }
    public static var persistentStoreIncompleteSave: CocoaError.Code { .persistentStoreIncompleteSave }
    public static var coreData: CocoaError.Code { .coreData }
    public static var persistentStoreOperation: CocoaError.Code { .persistentStoreOperation }
    public static var persistentStoreOpen: CocoaError.Code { .persistentStoreOpen }
    public static var persistentStoreTimeout: CocoaError.Code { .persistentStoreTimeout }
    public static var persistentStoreUnsupportedRequestType: CocoaError.Code { .persistentStoreUnsupportedRequestType }
    public static var persistentStoreIncompatibleVersionHash: CocoaError.Code { .persistentStoreIncompatibleVersionHash }
    public static var migration: CocoaError.Code { .migration }
    public static var migrationCancelled: CocoaError.Code { .migrationCancelled }
    public static var migrationMissingSourceModel: CocoaError.Code { .migrationMissingSourceModel }
    public static var migrationMissingMappingModel: CocoaError.Code { .migrationMissingMappingModel }
    public static var migrationManagerSourceStore: CocoaError.Code { .migrationManagerSourceStore }
    public static var migrationManagerDestinationStore: CocoaError.Code { .migrationManagerDestinationStore }
    public static var entityMigrationPolicy: CocoaError.Code { .entityMigrationPolicy }
    public static var sqlite: CocoaError.Code { .sqlite }
    public static var inferredMappingModel: CocoaError.Code { .inferredMappingModel }
    public static var externalRecordImport: CocoaError.Code { .externalRecordImport }
    @available(swift, deprecated: 4.2, renamed: "fileNoSuchFile") public static var fileNoSuchFileError: CocoaError.Code { .fileNoSuchFile }
    @available(swift, deprecated: 4.2, renamed: "fileLocking") public static var fileLockingError: CocoaError.Code { .fileLocking }
    @available(swift, deprecated: 4.2, renamed: "fileReadUnknown") public static var fileReadUnknownError: CocoaError.Code { .fileReadUnknown }
    @available(swift, deprecated: 4.2, renamed: "fileReadNoPermission") public static var fileReadNoPermissionError: CocoaError.Code { .fileReadNoPermission }
    @available(swift, deprecated: 4.2, renamed: "fileReadInvalidFileName") public static var fileReadInvalidFileNameError: CocoaError.Code { .fileReadInvalidFileName }
    @available(swift, deprecated: 4.2, renamed: "fileReadCorruptFile") public static var fileReadCorruptFileError: CocoaError.Code { .fileReadCorruptFile }
    @available(swift, deprecated: 4.2, renamed: "fileReadNoSuchFile") public static var fileReadNoSuchFileError: CocoaError.Code { .fileReadNoSuchFile }
    @available(swift, deprecated: 4.2, renamed: "fileReadInapplicableStringEncoding") public static var fileReadInapplicableStringEncodingError: CocoaError.Code { .fileReadInapplicableStringEncoding }
    @available(swift, deprecated: 4.2, renamed: "fileReadUnsupportedScheme") public static var fileReadUnsupportedSchemeError: CocoaError.Code { .fileReadUnsupportedScheme }
    @available(swift, deprecated: 4.2, renamed: "fileReadTooLarge") public static var fileReadTooLargeError: CocoaError.Code { .fileReadTooLarge }
    @available(swift, deprecated: 4.2, renamed: "fileReadUnknownStringEncoding") public static var fileReadUnknownStringEncodingError: CocoaError.Code { .fileReadUnknownStringEncoding }
    @available(swift, deprecated: 4.2, renamed: "fileWriteUnknown") public static var fileWriteUnknownError: CocoaError.Code { .fileWriteUnknown }
    @available(swift, deprecated: 4.2, renamed: "fileWriteNoPermission") public static var fileWriteNoPermissionError: CocoaError.Code { .fileWriteNoPermission }
    @available(swift, deprecated: 4.2, renamed: "fileWriteInvalidFileName") public static var fileWriteInvalidFileNameError: CocoaError.Code { .fileWriteInvalidFileName }
    @available(swift, deprecated: 4.2, renamed: "fileWriteFileExists") public static var fileWriteFileExistsError: CocoaError.Code { .fileWriteFileExists }
    @available(swift, deprecated: 4.2, renamed: "fileWriteInapplicableStringEncoding") public static var fileWriteInapplicableStringEncodingError: CocoaError.Code { .fileWriteInapplicableStringEncoding }
    @available(swift, deprecated: 4.2, renamed: "fileWriteUnsupportedScheme") public static var fileWriteUnsupportedSchemeError: CocoaError.Code { .fileWriteUnsupportedScheme }
    @available(swift, deprecated: 4.2, renamed: "fileWriteOutOfSpace") public static var fileWriteOutOfSpaceError: CocoaError.Code { .fileWriteOutOfSpace }
    @available(swift, deprecated: 4.2, renamed: "fileWriteVolumeReadOnly") public static var fileWriteVolumeReadOnlyError: CocoaError.Code { .fileWriteVolumeReadOnly }
    @available(swift, deprecated: 4.2, renamed: "keyValueValidation") public static var keyValueValidationError: CocoaError.Code { .keyValueValidation }
    @available(swift, deprecated: 4.2, renamed: "formatting") public static var formattingError: CocoaError.Code { .formatting }
    @available(swift, deprecated: 4.2, renamed: "userCancelled") public static var userCancelledError: CocoaError.Code { .userCancelled }
    @available(swift, deprecated: 4.2, renamed: "featureUnsupported") public static var featureUnsupportedError: CocoaError.Code { .featureUnsupported }
    @available(swift, deprecated: 4.2, renamed: "propertyListReadCorrupt") public static var propertyListReadCorruptError: CocoaError.Code { .propertyListReadCorrupt }
    @available(swift, deprecated: 4.2, renamed: "propertyListReadUnknownVersion") public static var propertyListReadUnknownVersionError: CocoaError.Code { .propertyListReadUnknownVersion }
    @available(swift, deprecated: 4.2, renamed: "propertyListReadStream") public static var propertyListReadStreamError: CocoaError.Code { .propertyListReadStream }
    @available(swift, deprecated: 4.2, renamed: "propertyListWriteStream") public static var propertyListWriteStreamError: CocoaError.Code { .propertyListWriteStream }
    @available(swift, deprecated: 4.2, renamed: "propertyListWriteInvalid") public static var propertyListWriteInvalidError: CocoaError.Code { .propertyListWriteInvalid }
    @available(swift, deprecated: 4.2, renamed: "coderReadCorrupt") public static var coderReadCorruptError: CocoaError.Code { .coderReadCorrupt }
    @available(swift, deprecated: 4.2, renamed: "coderValueNotFound") public static var coderValueNotFoundError: CocoaError.Code { .coderValueNotFound }
    @available(swift, deprecated: 4.2, renamed: "executableNotLoadable") public static var executableNotLoadableError: CocoaError.Code { .executableNotLoadable }
    @available(swift, deprecated: 4.2, renamed: "executableArchitectureMismatch") public static var executableArchitectureMismatchError: CocoaError.Code { .executableArchitectureMismatch }
    @available(swift, deprecated: 4.2, renamed: "executableRuntimeMismatch") public static var executableRuntimeMismatchError: CocoaError.Code { .executableRuntimeMismatch }
    @available(swift, deprecated: 4.2, renamed: "executableLoad") public static var executableLoadError: CocoaError.Code { .executableLoad }
    @available(swift, deprecated: 4.2, renamed: "executableLink") public static var executableLinkError: CocoaError.Code { .executableLink }
    @available(swift, deprecated: 4.2, renamed: "ubiquitousFileUnavailable") public static var ubiquitousFileUnavailableError: CocoaError.Code { .ubiquitousFileUnavailable }
    @available(swift, deprecated: 4.2, renamed: "ubiquitousFileNotUploadedDueToQuota") public static var ubiquitousFileNotUploadedDueToQuotaError: CocoaError.Code { .ubiquitousFileNotUploadedDueToQuota }
    @available(swift, deprecated: 4.2, renamed: "userActivityHandoffFailed") public static var userActivityHandoffFailedError: CocoaError.Code { .userActivityHandoffFailed }
    @available(swift, deprecated: 4.2, renamed: "userActivityConnectionUnavailable") public static var userActivityConnectionUnavailableError: CocoaError.Code { .userActivityConnectionUnavailable }
    @available(swift, deprecated: 4.2, renamed: "userActivityRemoteApplicationTimedOut") public static var userActivityRemoteApplicationTimedOutError: CocoaError.Code { .userActivityRemoteApplicationTimedOut }
    @available(swift, deprecated: 4.2, renamed: "userActivityHandoffUserInfoTooLarge") public static var userActivityHandoffUserInfoTooLargeError: CocoaError.Code { .userActivityHandoffUserInfoTooLarge }
    @available(swift, deprecated: 4.2, renamed: "managedObjectValidation") public static var managedObjectValidationError: CocoaError.Code { .managedObjectValidation }
    @available(swift, deprecated: 4.2, renamed: "validationMultipleErrors") public static var validationMultipleErrorsError: CocoaError.Code { .validationMultipleErrors }
    @available(swift, deprecated: 4.2, renamed: "validationMissingMandatoryProperty") public static var validationMissingMandatoryPropertyError: CocoaError.Code { .validationMissingMandatoryProperty }
    @available(swift, deprecated: 4.2, renamed: "validationRelationshipLacksMinimumCount") public static var validationRelationshipLacksMinimumCountError: CocoaError.Code { .validationRelationshipLacksMinimumCount }
    @available(swift, deprecated: 4.2, renamed: "validationRelationshipExceedsMaximumCount") public static var validationRelationshipExceedsMaximumCountError: CocoaError.Code { .validationRelationshipExceedsMaximumCount }
    @available(swift, deprecated: 4.2, renamed: "validationRelationshipDeniedDelete") public static var validationRelationshipDeniedDeleteError: CocoaError.Code { .validationRelationshipDeniedDelete }
    @available(swift, deprecated: 4.2, renamed: "validationNumberTooLarge") public static var validationNumberTooLargeError: CocoaError.Code { .validationNumberTooLarge }
    @available(swift, deprecated: 4.2, renamed: "validationNumberTooSmall") public static var validationNumberTooSmallError: CocoaError.Code { .validationNumberTooSmall }
    @available(swift, deprecated: 4.2, renamed: "validationDateTooLate") public static var validationDateTooLateError: CocoaError.Code { .validationDateTooLate }
    @available(swift, deprecated: 4.2, renamed: "validationDateTooSoon") public static var validationDateTooSoonError: CocoaError.Code { .validationDateTooSoon }
    @available(swift, deprecated: 4.2, renamed: "validationInvalidDate") public static var validationInvalidDateError: CocoaError.Code { .validationInvalidDate }
    @available(swift, deprecated: 4.2, renamed: "validationStringTooLong") public static var validationStringTooLongError: CocoaError.Code { .validationStringTooLong }
    @available(swift, deprecated: 4.2, renamed: "validationStringTooShort") public static var validationStringTooShortError: CocoaError.Code { .validationStringTooShort }
    @available(swift, deprecated: 4.2, renamed: "validationStringPatternMatching") public static var validationStringPatternMatchingError: CocoaError.Code { .validationStringPatternMatching }
    @available(swift, deprecated: 4.2, renamed: "managedObjectContextLocking") public static var managedObjectContextLockingError: CocoaError.Code { .managedObjectContextLocking }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreCoordinatorLocking") public static var persistentStoreCoordinatorLockingError: CocoaError.Code { .persistentStoreCoordinatorLocking }
    @available(swift, deprecated: 4.2, renamed: "managedObjectReferentialIntegrity") public static var managedObjectReferentialIntegrityError: CocoaError.Code { .managedObjectReferentialIntegrity }
    @available(swift, deprecated: 4.2, renamed: "managedObjectExternalRelationship") public static var managedObjectExternalRelationshipError: CocoaError.Code { .managedObjectExternalRelationship }
    @available(swift, deprecated: 4.2, renamed: "managedObjectMerge") public static var managedObjectMergeError: CocoaError.Code { .managedObjectMerge }
    @available(swift, deprecated: 4.2, renamed: "managedObjectConstraintMerge") public static var managedObjectConstraintMergeError: CocoaError.Code { .managedObjectConstraintMerge }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreInvalidType") public static var persistentStoreInvalidTypeError: CocoaError.Code { .persistentStoreInvalidType }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreTypeMismatch") public static var persistentStoreTypeMismatchError: CocoaError.Code { .persistentStoreTypeMismatch }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreIncompatibleSchema") public static var persistentStoreIncompatibleSchemaError: CocoaError.Code { .persistentStoreIncompatibleSchema }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreSave") public static var persistentStoreSaveError: CocoaError.Code { .persistentStoreSave }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreIncompleteSave") public static var persistentStoreIncompleteSaveError: CocoaError.Code { .persistentStoreIncompleteSave }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreSaveConflicts") public static var persistentStoreSaveConflictsError: CocoaError.Code { .persistentStoreSaveConflicts }
    @available(swift, deprecated: 4.2, renamed: "coreData") public static var coreDataError: CocoaError.Code { .coreData }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreOperation") public static var persistentStoreOperationError: CocoaError.Code { .persistentStoreOperation }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreOpen") public static var persistentStoreOpenError: CocoaError.Code { .persistentStoreOpen }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreTimeout") public static var persistentStoreTimeoutError: CocoaError.Code { .persistentStoreTimeout }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreUnsupportedRequestType") public static var persistentStoreUnsupportedRequestTypeError: CocoaError.Code { .persistentStoreUnsupportedRequestType }
    @available(swift, deprecated: 4.2, renamed: "persistentStoreIncompatibleVersionHash") public static var persistentStoreIncompatibleVersionHashError: CocoaError.Code { .persistentStoreIncompatibleVersionHash }
    @available(swift, deprecated: 4.2, renamed: "migration") public static var migrationError: CocoaError.Code { .migration }
    @available(swift, deprecated: 4.2, renamed: "migrationCancelled") public static var migrationCancelledError: CocoaError.Code { .migrationCancelled }
    @available(swift, deprecated: 4.2, renamed: "migrationMissingSourceModel") public static var migrationMissingSourceModelError: CocoaError.Code { .migrationMissingSourceModel }
    @available(swift, deprecated: 4.2, renamed: "migrationMissingMappingModel") public static var migrationMissingMappingModelError: CocoaError.Code { .migrationMissingMappingModel }
    @available(swift, deprecated: 4.2, renamed: "migrationManagerSourceStore") public static var migrationManagerSourceStoreError: CocoaError.Code { .migrationManagerSourceStore }
    @available(swift, deprecated: 4.2, renamed: "migrationManagerDestinationStore") public static var migrationManagerDestinationStoreError: CocoaError.Code { .migrationManagerDestinationStore }
    @available(swift, deprecated: 4.2, renamed: "entityMigrationPolicy") public static var entityMigrationPolicyError: CocoaError.Code { .entityMigrationPolicy }
    @available(swift, deprecated: 4.2, renamed: "sqlite") public static var sqliteError: CocoaError.Code { .sqlite }
    @available(swift, deprecated: 4.2, renamed: "inferredMappingModel") public static var inferredMappingModelError: CocoaError.Code { .inferredMappingModel }
    @available(swift, deprecated: 4.2, renamed: "externalRecordImport") public static var externalRecordImportError: CocoaError.Code { .externalRecordImport }
    public static var persistentStoreSaveConflicts: CocoaError.Code { .persistentStoreSaveConflicts }
}
extension CocoaError {
    public var isExecutableError: Bool { (3584...3839).contains(code.rawValue) }
    public var isUbiquitousFileError: Bool { (4352...4607).contains(code.rawValue) }
    public var isUserActivityError: Bool { (4608...4863).contains(code.rawValue) }
    public var isXPCConnectionError: Bool { (4096...4224).contains(code.rawValue) }
    /// NSUnderlyingErrorKey and NSMultipleUnderlyingErrorsKey, in that order
    public var underlyingErrors: [any Error] {
        var all: [any Error] = []
        if let e = errorUserInfo[NSUnderlyingErrorKey] as? Error { all.append(e) }
        if let es = errorUserInfo["NSMultipleUnderlyingErrorsKey"] as? [Error] { all += es }
        return all
    }
    // Core Data's userInfo (CoreDataErrors.h keys)
    public var affectedObjects: [AnyObject]? { errorUserInfo["NSAffectedObjectsErrorKey"] as? [AnyObject] }
    public var affectedStores: [AnyObject]? { errorUserInfo["NSAffectedStoresErrorKey"] as? [AnyObject] }
    public var validationKey: String? { errorUserInfo["NSValidationErrorKey"] as? String }
    public var validationObject: Any? { errorUserInfo["NSValidationErrorObject"] }
    public var validationPredicate: NSPredicate? { errorUserInfo["NSValidationErrorPredicate"] as? NSPredicate }
    public var validationValue: Any? { errorUserInfo["NSValidationErrorValue"] }
}
