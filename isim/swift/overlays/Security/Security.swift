// isim Security: the keychain item API (SecItemAdd/CopyMatching/Update/Delete) for generic and internet
// passwords, SecRandomCopyBytes, SecCopyErrorMessageString and SecAccessControl (self-authored, iOS API names
// and constants; the attribute strings match iOS so stored dictionaries look the same).
//
// Items live in the device data directory, one file per access group: $ISIM_DATA/Library/Keychains/<group>.keychain
// (mode 0600, JSON; not encrypted — the host user can read it). An app's default access group is its bundle
// identifier; items survive app deletion like on iOS and are erased by `isim reset`. Access control flags
// (biometry, passcode) are stored but not enforced. Keys, certificates and identities are not supported
// (errSecUnimplemented).
import Foundation

public typealias OSStatus = Int32
public typealias SecRandomRef = OpaquePointer

public let errSecSuccess: OSStatus = 0
public let errSecUnimplemented: OSStatus = -4
public let errSecIO: OSStatus = -36
public let errSecParam: OSStatus = -50
public let errSecAllocate: OSStatus = -108
public let errSecUserCanceled: OSStatus = -128
public let errSecBadReq: OSStatus = -909
public let errSecNotAvailable: OSStatus = -25291
public let errSecReadOnly: OSStatus = -25292
public let errSecAuthFailed: OSStatus = -25293
public let errSecNoSuchKeychain: OSStatus = -25294
public let errSecDuplicateItem: OSStatus = -25299
public let errSecItemNotFound: OSStatus = -25300
public let errSecInteractionNotAllowed: OSStatus = -25308
public let errSecDecode: OSStatus = -26275
public let errSecMissingEntitlement: OSStatus = -34018

// MARK: - Keys and values

public let kSecClass: CFString = "class" as CFString
public let kSecClassGenericPassword: CFString = "genp" as CFString
public let kSecClassInternetPassword: CFString = "inet" as CFString
public let kSecClassCertificate: CFString = "cert" as CFString
public let kSecClassKey: CFString = "keys" as CFString
public let kSecClassIdentity: CFString = "idnt" as CFString

public let kSecAttrAccessible: CFString = "pdmn" as CFString
public let kSecAttrAccessibleWhenUnlocked: CFString = "ak" as CFString
public let kSecAttrAccessibleAfterFirstUnlock: CFString = "ck" as CFString
public let kSecAttrAccessibleAlways: CFString = "dk" as CFString
public let kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly: CFString = "akpu" as CFString
public let kSecAttrAccessibleWhenUnlockedThisDeviceOnly: CFString = "aku" as CFString
public let kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly: CFString = "cku" as CFString
public let kSecAttrAccessibleAlwaysThisDeviceOnly: CFString = "dku" as CFString
public let kSecAttrAccessControl: CFString = "accc" as CFString
public let kSecAttrAccessGroup: CFString = "agrp" as CFString
public let kSecAttrSynchronizable: CFString = "sync" as CFString
public let kSecAttrSynchronizableAny: CFString = "syna" as CFString
public let kSecAttrCreationDate: CFString = "cdat" as CFString
public let kSecAttrModificationDate: CFString = "mdat" as CFString
public let kSecAttrDescription: CFString = "desc" as CFString
public let kSecAttrComment: CFString = "icmt" as CFString
public let kSecAttrCreator: CFString = "crtr" as CFString
public let kSecAttrType: CFString = "type" as CFString
public let kSecAttrLabel: CFString = "labl" as CFString
public let kSecAttrIsInvisible: CFString = "invi" as CFString
public let kSecAttrIsNegative: CFString = "nega" as CFString
public let kSecAttrAccount: CFString = "acct" as CFString
public let kSecAttrService: CFString = "svce" as CFString
public let kSecAttrGeneric: CFString = "gena" as CFString
public let kSecAttrSecurityDomain: CFString = "sdmn" as CFString
public let kSecAttrServer: CFString = "srvr" as CFString
public let kSecAttrProtocol: CFString = "ptcl" as CFString
public let kSecAttrAuthenticationType: CFString = "atyp" as CFString
public let kSecAttrPort: CFString = "port" as CFString
public let kSecAttrPath: CFString = "path" as CFString

public let kSecAttrProtocolFTP: CFString = "ftp " as CFString
public let kSecAttrProtocolHTTP: CFString = "http" as CFString
public let kSecAttrProtocolHTTPS: CFString = "htps" as CFString
public let kSecAttrProtocolSSH: CFString = "ssh " as CFString
public let kSecAttrProtocolSMTP: CFString = "smtp" as CFString
public let kSecAttrProtocolIMAP: CFString = "imap" as CFString
public let kSecAttrAuthenticationTypeDefault: CFString = "dflt" as CFString
public let kSecAttrAuthenticationTypeHTTPBasic: CFString = "http" as CFString
public let kSecAttrAuthenticationTypeHTTPDigest: CFString = "httd" as CFString
public let kSecAttrAuthenticationTypeHTMLForm: CFString = "form" as CFString

public let kSecMatchLimit: CFString = "m_Limit" as CFString
public let kSecMatchLimitOne: CFString = "m_LimitOne" as CFString
public let kSecMatchLimitAll: CFString = "m_LimitAll" as CFString
public let kSecMatchCaseInsensitive: CFString = "m_CaseInsensitive" as CFString

public let kSecReturnData: CFString = "r_Data" as CFString
public let kSecReturnAttributes: CFString = "r_Attributes" as CFString
public let kSecReturnRef: CFString = "r_Ref" as CFString
public let kSecReturnPersistentRef: CFString = "r_PersistentRef" as CFString

public let kSecValueData: CFString = "v_Data" as CFString
public let kSecValueRef: CFString = "v_Ref" as CFString
public let kSecValuePersistentRef: CFString = "v_PersistentRef" as CFString

public let kSecUseDataProtectionKeychain: CFString = "nleg" as CFString
public let kSecUseAuthenticationUI: CFString = "u_AuthUI" as CFString
public let kSecUseAuthenticationUIAllow: CFString = "u_AuthUIA" as CFString
public let kSecUseAuthenticationUIFail: CFString = "u_AuthUIF" as CFString
public let kSecUseAuthenticationUISkip: CFString = "u_AuthUIS" as CFString
public let kSecUseAuthenticationContext: CFString = "u_AuthCtx" as CFString
public let kSecUseOperationPrompt: CFString = "u_OpPrompt" as CFString

// MARK: - Random numbers

public let kSecRandomDefault: SecRandomRef? = nil
public func SecRandomCopyBytes(_ rnd: SecRandomRef?, _ count: Int, _ bytes: UnsafeMutableRawPointer) -> Int32 {
    arc4random_buf(bytes, count)
    return errSecSuccess
}

// MARK: - Access control (stored with the item, not enforced on isim)

public struct SecAccessControlCreateFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let userPresence = SecAccessControlCreateFlags(rawValue: 1 << 0)
    public static let biometryAny = SecAccessControlCreateFlags(rawValue: 1 << 1)
    @available(*, deprecated, renamed: "biometryAny") public static let touchIDAny = SecAccessControlCreateFlags(rawValue: 1 << 1)
    public static let biometryCurrentSet = SecAccessControlCreateFlags(rawValue: 1 << 3)
    @available(*, deprecated, renamed: "biometryCurrentSet") public static let touchIDCurrentSet = SecAccessControlCreateFlags(rawValue: 1 << 3)
    public static let devicePasscode = SecAccessControlCreateFlags(rawValue: 1 << 4)
    public static let watch = SecAccessControlCreateFlags(rawValue: 1 << 5)
    public static let or = SecAccessControlCreateFlags(rawValue: 1 << 14)
    public static let and = SecAccessControlCreateFlags(rawValue: 1 << 15)
    public static let privateKeyUsage = SecAccessControlCreateFlags(rawValue: 1 << 30)
    public static let applicationPassword = SecAccessControlCreateFlags(rawValue: 1 << 31)
}
public final class SecAccessControl: NSObject {
    let protection: String, flags: SecAccessControlCreateFlags
    init(protection: String, flags: SecAccessControlCreateFlags) { self.protection = protection; self.flags = flags }
}
public func SecAccessControlCreateWithFlags(_ allocator: CFAllocator?, _ protection: CFTypeRef, _ flags: SecAccessControlCreateFlags,
                                            _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> SecAccessControl? {
    SecAccessControl(protection: (protection as? String) ?? "ak", flags: flags)
}

// MARK: - Error messages

public func SecCopyErrorMessageString(_ status: OSStatus, _ reserved: UnsafeMutableRawPointer?) -> CFString? {
    let m: String
    switch status {
    case errSecSuccess: m = "No error."
    case errSecUnimplemented: m = "Function or operation not implemented."
    case errSecIO: m = "I/O error."
    case errSecParam: m = "One or more parameters passed to a function were not valid."
    case errSecAllocate: m = "Failed to allocate memory."
    case errSecUserCanceled: m = "User canceled the operation."
    case errSecBadReq: m = "Bad parameter or invalid state for operation."
    case errSecNotAvailable: m = "No keychain is available."
    case errSecAuthFailed: m = "The user name or passphrase you entered is not correct."
    case errSecDuplicateItem: m = "The specified item already exists in the keychain."
    case errSecItemNotFound: m = "The specified item could not be found in the keychain."
    case errSecInteractionNotAllowed: m = "User interaction is not allowed."
    case errSecDecode: m = "Unable to decode the provided data."
    case errSecMissingEntitlement: m = "A required entitlement isn't present."
    default: m = "OSStatus \(status)"
    }
    return m as CFString
}

// MARK: - SecItem

public func SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    _Keychain.shared.add(_Keychain.dict(attributes), result)
}
public func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
    _Keychain.shared.copyMatching(_Keychain.dict(query), result)
}
public func SecItemUpdate(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus {
    _Keychain.shared.update(_Keychain.dict(query), _Keychain.dict(attributesToUpdate))
}
public func SecItemDelete(_ query: CFDictionary) -> OSStatus {
    _Keychain.shared.delete(_Keychain.dict(query))
}
