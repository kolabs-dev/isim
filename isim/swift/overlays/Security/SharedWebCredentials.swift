// isim Security: shared web credentials (SecAddSharedWebCredential, SecRequestSharedWebCredential,
// SecCreateSharedWebCredentialPassword; adapted). The credentials are the device's Passwords store
// ($ISIM_DATA/Library/Passwords/passwords.plist, the one AutoFill and Settings > Passwords use; there is no iCloud
// Keychain), for the app's `webcredentials:` associated domains that the domain's apple-app-site-association confirms
// (UIKit's UIUniversalLinks.m). Saving, updating and deleting ask the user, and a request lets the user choose a saved
// account (UIKit's UITextServices.m, found at run time: without UIKit the functions fail with errSecNotAvailable).
import Foundation

/// the password in a credential SecRequestSharedWebCredential returns
public let kSecSharedPassword: CFString = "spwd" as CFString

private typealias _AddFn = @convention(c) (NSString, NSString, NSString?, @escaping @convention(block) (Int32) -> Void) -> Void
private typealias _RequestFn = @convention(c) (NSString?, NSString?, @escaping @convention(block) (NSArray?, Int32) -> Void) -> Void

/// UIKit's half (loaded in every app with a user interface)
private func _uikit(_ name: String) -> UnsafeMutableRawPointer? { dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) }   // RTLD_DEFAULT
private func _sharedCredentialError(_ status: OSStatus) -> CFError? {
    guard status != errSecSuccess else { return nil }
    let message: String
    switch status {
    case -25300: message = "no shared web credential was found"
    case -128: message = "the user declined"
    case -34018: message = "the domain is not one of the app's webcredentials associated domains"
    default: message = "shared web credentials are not available"
    }
    let e = NSError(domain: "NSOSStatusErrorDomain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
    return unsafeBitCast(e, to: CFError.self)
}

/// Saves (password non-nil) or deletes (nil) the account's password for the fully qualified domain, after asking the user.
public func SecAddSharedWebCredential(_ fqdn: CFString, _ account: CFString, _ password: CFString?,
                                      _ completionHandler: @escaping @Sendable (CFError?) -> Void) {
    guard let sym = _uikit("isim_ui_shared_web_credential_add") else { completionHandler(_sharedCredentialError(-25291)); return }
    unsafeBitCast(sym, to: _AddFn.self)(fqdn as NSString, account as NSString, password as NSString?) { status in
        completionHandler(_sharedCredentialError(status))
    }
}

/// The saved credential the user chooses for the domain (nil: any of the app's webcredentials domains) and account
/// (nil: any): an array of one dictionary with kSecAttrServer, kSecAttrAccount and kSecSharedPassword.
@available(iOS, deprecated: 14.0, message: "Use ASAuthorizationController with ASAuthorizationPasswordRequest")
public func SecRequestSharedWebCredential(_ fqdn: CFString?, _ account: CFString?,
                                          _ completionHandler: @escaping @Sendable (CFArray?, CFError?) -> Void) {
    _SecRequestSharedWebCredential(fqdn, account, completionHandler)
}

/// A strong password like Safari suggests: four groups of three characters, "xxx-xxx-xxx-xxx", with upper and lower
/// case letters and digits.
public func SecCreateSharedWebCredentialPassword() -> CFString? {
    let lower = Array("abcdefghijkmnopqrstuvwxyz"), upper = Array("ABCDEFGHJKLMNPQRSTUVWXYZ"), digits = Array("23456789")
    func pick(_ a: [Character]) -> Character { a[Int(arc4random_uniform(UInt32(a.count)))] }
    var chars = (0..<12).map { _ in pick(lower) }
    var slots = Array(0..<12).shuffled()
    chars[slots.removeFirst()] = pick(upper)
    chars[slots.removeFirst()] = pick(digits)
    let groups = stride(from: 0, to: 12, by: 3).map { String(chars[$0..<($0 + 3)]) }
    return groups.joined(separator: "-") as CFString
}

// MARK: - C

@_cdecl("SecAddSharedWebCredential")
public func _c_SecAddSharedWebCredential(_ fqdn: CFString, _ account: CFString, _ password: CFString?,
                                         _ completionHandler: @escaping @convention(block) (CFError?) -> Void) {
    SecAddSharedWebCredential(fqdn, account, password) { completionHandler($0) }
}
@_cdecl("SecRequestSharedWebCredential")
public func _c_SecRequestSharedWebCredential(_ fqdn: CFString?, _ account: CFString?,
                                             _ completionHandler: @escaping @convention(block) (CFArray?, CFError?) -> Void) {
    _SecRequestSharedWebCredential(fqdn, account) { completionHandler($0, $1) }
}
@_cdecl("SecCreateSharedWebCredentialPassword")
public func _c_SecCreateSharedWebCredentialPassword() -> Unmanaged<CFString>? {
    SecCreateSharedWebCredentialPassword().map { Unmanaged.passRetained($0) }
}
/// the request without the deprecation warning (for the C entry point)
private func _SecRequestSharedWebCredential(_ fqdn: CFString?, _ account: CFString?, _ done: @escaping @Sendable (CFArray?, CFError?) -> Void) {
    guard let sym = _uikit("isim_ui_shared_web_credential_request") else { done(nil, _sharedCredentialError(-25291)); return }
    unsafeBitCast(sym, to: _RequestFn.self)(fqdn as NSString?, account as NSString?) { list, status in
        done(list.map { unsafeBitCast($0, to: CFArray.self) }, _sharedCredentialError(status))
    }
}
