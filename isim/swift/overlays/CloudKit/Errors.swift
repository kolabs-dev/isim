// CKError (isim CloudKit).
import Foundation

public let CKErrorDomain = "CKErrorDomain"
public let CKPartialErrorsByItemIDKey = "CKPartialErrors"
public let CKRecordChangedErrorAncestorRecordKey = "AncestorRecord"
public let CKRecordChangedErrorServerRecordKey = "ServerRecord"
public let CKRecordChangedErrorClientRecordKey = "ClientRecord"
public let CKErrorRetryAfterKey = "CKRetryAfter"

public struct CKError: Error, CustomNSError, Hashable, @unchecked Sendable {
    public enum Code: Int, Sendable {
        case internalError = 1, partialFailure = 2, networkUnavailable = 3, networkFailure = 4, badContainer = 5, serviceUnavailable = 6
        case requestRateLimited = 7, missingEntitlement = 8, notAuthenticated = 9, permissionFailure = 10, unknownItem = 11
        case invalidArguments = 12, resultsTruncated = 13, serverRecordChanged = 14, serverRejectedRequest = 15, assetFileNotFound = 16
        case assetFileModified = 17, incompatibleVersion = 18, constraintViolation = 19, operationCancelled = 20, changeTokenExpired = 21
        case batchRequestFailed = 22, zoneBusy = 23, badDatabase = 24, quotaExceeded = 25, zoneNotFound = 26, limitExceeded = 27
        case userDeletedZone = 28, tooManyParticipants = 29, alreadyShared = 30, referenceViolation = 31, managedAccountRestricted = 32
        case participantMayNeedVerification = 33, serverResponseLost = 34, assetNotAvailable = 35, accountTemporarilyUnavailable = 36
    }
    public let code: Code
    let info: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; info = userInfo }
    public static var errorDomain: String { CKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        var u = info
        if u[NSLocalizedDescriptionKey] == nil { u[NSLocalizedDescriptionKey] = CKError.text(code) }
        return u
    }
    public var userInfo: [String: Any] { errorUserInfo }
    public var localizedDescription: String { errorUserInfo[NSLocalizedDescriptionKey] as? String ?? "CloudKit error \(code.rawValue)" }
    public static func == (a: CKError, b: CKError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }

    public var serverRecord: CKRecord? { info[CKRecordChangedErrorServerRecordKey] as? CKRecord }
    public var clientRecord: CKRecord? { info[CKRecordChangedErrorClientRecordKey] as? CKRecord }
    public var ancestorRecord: CKRecord? { info[CKRecordChangedErrorAncestorRecordKey] as? CKRecord }
    public var partialErrorsByItemID: [AnyHashable: Error]? { info[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] }
    public var retryAfterSeconds: Double? { info[CKErrorRetryAfterKey] as? Double }

    static func text(_ c: Code) -> String {
        switch c {
        case .notAuthenticated: return "No iCloud account is signed in on this device (isim: ISIM_ICLOUD=noAccount)."
        case .unknownItem: return "Record not found"
        case .serverRecordChanged: return "record to insert already exists"
        case .zoneNotFound: return "Zone does not exist"
        case .partialFailure: return "Failed to modify some records"
        case .invalidArguments: return "Invalid arguments"
        case .permissionFailure: return "Permission failure"
        case .operationCancelled: return "Operation cancelled"
        case .batchRequestFailed: return "Atomic failure"
        default: return "CloudKit error \(c.rawValue)"
        }
    }

    public static var internalError: Code { .internalError }
    public static var partialFailure: Code { .partialFailure }
    public static var networkUnavailable: Code { .networkUnavailable }
    public static var networkFailure: Code { .networkFailure }
    public static var notAuthenticated: Code { .notAuthenticated }
    public static var permissionFailure: Code { .permissionFailure }
    public static var unknownItem: Code { .unknownItem }
    public static var invalidArguments: Code { .invalidArguments }
    public static var serverRecordChanged: Code { .serverRecordChanged }
    public static var zoneNotFound: Code { .zoneNotFound }
    public static var operationCancelled: Code { .operationCancelled }
    public static var batchRequestFailed: Code { .batchRequestFailed }
    public static var quotaExceeded: Code { .quotaExceeded }
    public static var limitExceeded: Code { .limitExceeded }
    public static var changeTokenExpired: Code { .changeTokenExpired }
    public static var accountTemporarilyUnavailable: Code { .accountTemporarilyUnavailable }
}

/// `catch CKError.serverRecordChanged { ... }`
public func ~= (code: CKError.Code, error: Error) -> Bool {
    if let e = error as? CKError { return e.code == code }
    let n = error as NSError
    return n.domain == CKErrorDomain && n.code == code.rawValue
}
