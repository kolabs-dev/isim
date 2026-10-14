// POSIXError and MachError: the Swift face of NSPOSIXErrorDomain and NSMachErrorDomain errors, as Apple's Foundation
// overlay (`catch POSIXError.ENOENT`, `POSIXError(.EACCES)`). Their codes are Darwin's POSIXErrorCode and MachErrorCode
// (the Darwin overlay). An NSError of either domain bridges to them through _ObjectiveCBridgeableError.

public struct POSIXError: Error, CustomNSError, Hashable, _ObjectiveCBridgeableError, @unchecked Sendable {
    public typealias Code = POSIXErrorCode
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; errorUserInfo = userInfo }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == NSPOSIXErrorDomain, let code = Code(rawValue: Int32(truncatingIfNeeded: e.code)) else { return nil }
        self.init(code, userInfo: e.userInfo)
    }
    public static var errorDomain: String { NSPOSIXErrorDomain }
    public var errorCode: Int { Int(code.rawValue) }
    public var userInfo: [String: Any] { errorUserInfo }
    public static func == (a: POSIXError, b: POSIXError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
}
extension POSIXErrorCode {
    /// `catch POSIXError.ENOENT`
    public static func ~= (match: POSIXErrorCode, error: Error) -> Bool { (error as? POSIXError)?.code == match }
}
extension POSIXError {
    public static var EPERM: POSIXError.Code { .EPERM }
    public static var ENOENT: POSIXError.Code { .ENOENT }
    public static var ESRCH: POSIXError.Code { .ESRCH }
    public static var EINTR: POSIXError.Code { .EINTR }
    public static var EIO: POSIXError.Code { .EIO }
    public static var ENXIO: POSIXError.Code { .ENXIO }
    public static var E2BIG: POSIXError.Code { .E2BIG }
    public static var ENOEXEC: POSIXError.Code { .ENOEXEC }
    public static var EBADF: POSIXError.Code { .EBADF }
    public static var ECHILD: POSIXError.Code { .ECHILD }
    public static var EDEADLK: POSIXError.Code { .EDEADLK }
    public static var ENOMEM: POSIXError.Code { .ENOMEM }
    public static var EACCES: POSIXError.Code { .EACCES }
    public static var EFAULT: POSIXError.Code { .EFAULT }
    public static var ENOTBLK: POSIXError.Code { .ENOTBLK }
    public static var EBUSY: POSIXError.Code { .EBUSY }
    public static var EEXIST: POSIXError.Code { .EEXIST }
    public static var EXDEV: POSIXError.Code { .EXDEV }
    public static var ENODEV: POSIXError.Code { .ENODEV }
    public static var ENOTDIR: POSIXError.Code { .ENOTDIR }
    public static var EISDIR: POSIXError.Code { .EISDIR }
    public static var EINVAL: POSIXError.Code { .EINVAL }
    public static var ENFILE: POSIXError.Code { .ENFILE }
    public static var EMFILE: POSIXError.Code { .EMFILE }
    public static var ENOTTY: POSIXError.Code { .ENOTTY }
    public static var ETXTBSY: POSIXError.Code { .ETXTBSY }
    public static var EFBIG: POSIXError.Code { .EFBIG }
    public static var ENOSPC: POSIXError.Code { .ENOSPC }
    public static var ESPIPE: POSIXError.Code { .ESPIPE }
    public static var EROFS: POSIXError.Code { .EROFS }
    public static var EMLINK: POSIXError.Code { .EMLINK }
    public static var EPIPE: POSIXError.Code { .EPIPE }
    public static var EDOM: POSIXError.Code { .EDOM }
    public static var ERANGE: POSIXError.Code { .ERANGE }
    public static var EAGAIN: POSIXError.Code { .EAGAIN }
    public static var EINPROGRESS: POSIXError.Code { .EINPROGRESS }
    public static var EALREADY: POSIXError.Code { .EALREADY }
    public static var ENOTSOCK: POSIXError.Code { .ENOTSOCK }
    public static var EDESTADDRREQ: POSIXError.Code { .EDESTADDRREQ }
    public static var EMSGSIZE: POSIXError.Code { .EMSGSIZE }
    public static var EPROTOTYPE: POSIXError.Code { .EPROTOTYPE }
    public static var ENOPROTOOPT: POSIXError.Code { .ENOPROTOOPT }
    public static var EPROTONOSUPPORT: POSIXError.Code { .EPROTONOSUPPORT }
    public static var ESOCKTNOSUPPORT: POSIXError.Code { .ESOCKTNOSUPPORT }
    public static var ENOTSUP: POSIXError.Code { .ENOTSUP }
    public static var EPFNOSUPPORT: POSIXError.Code { .EPFNOSUPPORT }
    public static var EAFNOSUPPORT: POSIXError.Code { .EAFNOSUPPORT }
    public static var EADDRINUSE: POSIXError.Code { .EADDRINUSE }
    public static var EADDRNOTAVAIL: POSIXError.Code { .EADDRNOTAVAIL }
    public static var ENETDOWN: POSIXError.Code { .ENETDOWN }
    public static var ENETUNREACH: POSIXError.Code { .ENETUNREACH }
    public static var ENETRESET: POSIXError.Code { .ENETRESET }
    public static var ECONNABORTED: POSIXError.Code { .ECONNABORTED }
    public static var ECONNRESET: POSIXError.Code { .ECONNRESET }
    public static var ENOBUFS: POSIXError.Code { .ENOBUFS }
    public static var EISCONN: POSIXError.Code { .EISCONN }
    public static var ENOTCONN: POSIXError.Code { .ENOTCONN }
    public static var ESHUTDOWN: POSIXError.Code { .ESHUTDOWN }
    public static var ETOOMANYREFS: POSIXError.Code { .ETOOMANYREFS }
    public static var ETIMEDOUT: POSIXError.Code { .ETIMEDOUT }
    public static var ECONNREFUSED: POSIXError.Code { .ECONNREFUSED }
    public static var ELOOP: POSIXError.Code { .ELOOP }
    public static var ENAMETOOLONG: POSIXError.Code { .ENAMETOOLONG }
    public static var EHOSTDOWN: POSIXError.Code { .EHOSTDOWN }
    public static var EHOSTUNREACH: POSIXError.Code { .EHOSTUNREACH }
    public static var ENOTEMPTY: POSIXError.Code { .ENOTEMPTY }
    public static var EPROCLIM: POSIXError.Code { .EPROCLIM }
    public static var EUSERS: POSIXError.Code { .EUSERS }
    public static var EDQUOT: POSIXError.Code { .EDQUOT }
    public static var ESTALE: POSIXError.Code { .ESTALE }
    public static var EREMOTE: POSIXError.Code { .EREMOTE }
    public static var EBADRPC: POSIXError.Code { .EBADRPC }
    public static var ERPCMISMATCH: POSIXError.Code { .ERPCMISMATCH }
    public static var EPROGUNAVAIL: POSIXError.Code { .EPROGUNAVAIL }
    public static var EPROGMISMATCH: POSIXError.Code { .EPROGMISMATCH }
    public static var EPROCUNAVAIL: POSIXError.Code { .EPROCUNAVAIL }
    public static var ENOLCK: POSIXError.Code { .ENOLCK }
    public static var ENOSYS: POSIXError.Code { .ENOSYS }
    public static var EFTYPE: POSIXError.Code { .EFTYPE }
    public static var EAUTH: POSIXError.Code { .EAUTH }
    public static var ENEEDAUTH: POSIXError.Code { .ENEEDAUTH }
    public static var EPWROFF: POSIXError.Code { .EPWROFF }
    public static var EDEVERR: POSIXError.Code { .EDEVERR }
    public static var EOVERFLOW: POSIXError.Code { .EOVERFLOW }
    public static var EBADEXEC: POSIXError.Code { .EBADEXEC }
    public static var EBADARCH: POSIXError.Code { .EBADARCH }
    public static var ESHLIBVERS: POSIXError.Code { .ESHLIBVERS }
    public static var EBADMACHO: POSIXError.Code { .EBADMACHO }
    public static var ECANCELED: POSIXError.Code { .ECANCELED }
    public static var EIDRM: POSIXError.Code { .EIDRM }
    public static var ENOMSG: POSIXError.Code { .ENOMSG }
    public static var EILSEQ: POSIXError.Code { .EILSEQ }
    public static var ENOATTR: POSIXError.Code { .ENOATTR }
    public static var EBADMSG: POSIXError.Code { .EBADMSG }
    public static var EMULTIHOP: POSIXError.Code { .EMULTIHOP }
    public static var ENODATA: POSIXError.Code { .ENODATA }
    public static var ENOLINK: POSIXError.Code { .ENOLINK }
    public static var ENOSR: POSIXError.Code { .ENOSR }
    public static var ENOSTR: POSIXError.Code { .ENOSTR }
    public static var EPROTO: POSIXError.Code { .EPROTO }
    public static var ETIME: POSIXError.Code { .ETIME }
    public static var ENOPOLICY: POSIXError.Code { .ENOPOLICY }
    public static var ENOTRECOVERABLE: POSIXError.Code { .ENOTRECOVERABLE }
    public static var EOWNERDEAD: POSIXError.Code { .EOWNERDEAD }
    public static var EQFULL: POSIXError.Code { .EQFULL }
    public static var EWOULDBLOCK: POSIXError.Code { .EWOULDBLOCK }
    public static var ELAST: POSIXError.Code { .ELAST }
}

public struct MachError: Error, CustomNSError, Hashable, _ObjectiveCBridgeableError, @unchecked Sendable {
    public typealias Code = MachErrorCode
    public let code: Code
    public let errorUserInfo: [String: Any]
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code; errorUserInfo = userInfo }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == NSMachErrorDomain, let code = Code(rawValue: Int32(truncatingIfNeeded: e.code)) else { return nil }
        self.init(code, userInfo: e.userInfo)
    }
    public static var errorDomain: String { NSMachErrorDomain }
    public var errorCode: Int { Int(code.rawValue) }
    public var userInfo: [String: Any] { errorUserInfo }
    public static func == (a: MachError, b: MachError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
}
extension MachErrorCode {
    /// `catch MachError.invalidAddress`
    public static func ~= (match: MachErrorCode, error: Error) -> Bool { (error as? MachError)?.code == match }
}
extension MachError {
    public static var success: MachError.Code { .success }
    public static var invalidAddress: MachError.Code { .invalidAddress }
    public static var protectionFailure: MachError.Code { .protectionFailure }
    public static var noSpace: MachError.Code { .noSpace }
    public static var invalidArgument: MachError.Code { .invalidArgument }
    public static var failure: MachError.Code { .failure }
    public static var resourceShortage: MachError.Code { .resourceShortage }
    public static var notReceiver: MachError.Code { .notReceiver }
    public static var noAccess: MachError.Code { .noAccess }
    public static var memoryFailure: MachError.Code { .memoryFailure }
    public static var memoryError: MachError.Code { .memoryError }
    public static var alreadyInSet: MachError.Code { .alreadyInSet }
    public static var notInSet: MachError.Code { .notInSet }
    public static var nameExists: MachError.Code { .nameExists }
    public static var aborted: MachError.Code { .aborted }
    public static var invalidName: MachError.Code { .invalidName }
    public static var invalidTask: MachError.Code { .invalidTask }
    public static var invalidRight: MachError.Code { .invalidRight }
    public static var invalidValue: MachError.Code { .invalidValue }
    public static var userReferencesOverflow: MachError.Code { .userReferencesOverflow }
    public static var invalidCapability: MachError.Code { .invalidCapability }
    public static var rightExists: MachError.Code { .rightExists }
    public static var invalidHost: MachError.Code { .invalidHost }
    public static var memoryPresent: MachError.Code { .memoryPresent }
    public static var memoryDataMoved: MachError.Code { .memoryDataMoved }
    public static var memoryRestartCopy: MachError.Code { .memoryRestartCopy }
    public static var invalidProcessorSet: MachError.Code { .invalidProcessorSet }
    public static var policyLimit: MachError.Code { .policyLimit }
    public static var invalidPolicy: MachError.Code { .invalidPolicy }
    public static var invalidObject: MachError.Code { .invalidObject }
    public static var alreadyWaiting: MachError.Code { .alreadyWaiting }
    public static var defaultSet: MachError.Code { .defaultSet }
    public static var exceptionProtected: MachError.Code { .exceptionProtected }
    public static var invalidLedger: MachError.Code { .invalidLedger }
    public static var invalidMemoryControl: MachError.Code { .invalidMemoryControl }
    public static var invalidSecurity: MachError.Code { .invalidSecurity }
    public static var notDepressed: MachError.Code { .notDepressed }
    public static var terminated: MachError.Code { .terminated }
    public static var lockSetDestroyed: MachError.Code { .lockSetDestroyed }
    public static var lockUnstable: MachError.Code { .lockUnstable }
    public static var lockOwned: MachError.Code { .lockOwned }
    public static var lockOwnedSelf: MachError.Code { .lockOwnedSelf }
    public static var semaphoreDestroyed: MachError.Code { .semaphoreDestroyed }
    public static var rpcServerTerminated: MachError.Code { .rpcServerTerminated }
    public static var rpcTerminateOrphan: MachError.Code { .rpcTerminateOrphan }
    public static var rpcContinueOrphan: MachError.Code { .rpcContinueOrphan }
    public static var notSupported: MachError.Code { .notSupported }
    public static var nodeDown: MachError.Code { .nodeDown }
    public static var notWaiting: MachError.Code { .notWaiting }
    public static var operationTimedOut: MachError.Code { .operationTimedOut }
    public static var codesignError: MachError.Code { .codesignError }
    public static var policyStatic: MachError.Code { .policyStatic }
}
