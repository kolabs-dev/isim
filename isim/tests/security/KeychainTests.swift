// Keychain (Security framework) on isim: SecItemAdd/CopyMatching/Update/Delete with the usual app idioms.
import Foundation
import Security

func keychainTests() {
    let service = "dev.isim.test.\(getpid())"
    let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    _ = SecItemDelete(base as CFDictionary)

    var add = base
    add[kSecAttrAccount as String] = "alice"
    add[kSecAttrLabel as String] = "Alice's token"
    add[kSecValueData as String] = Data("s3cr3t".utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    check(SecItemAdd(add as CFDictionary, nil) == errSecSuccess, "SecItemAdd generic password")
    check(SecItemAdd(add as CFDictionary, nil) == errSecDuplicateItem, "SecItemAdd duplicate -> errSecDuplicateItem")

    var q = base
    q[kSecAttrAccount as String] = "alice"
    q[kSecReturnData as String] = kCFBooleanTrue
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    var st = SecItemCopyMatching(q as CFDictionary, &item)
    check(st == errSecSuccess && (item as? Data).map { String(decoding: $0, as: UTF8.self) } == "s3cr3t", "SecItemCopyMatching kSecReturnData")

    q[kSecReturnData as String] = nil
    q[kSecReturnAttributes as String] = true
    st = SecItemCopyMatching(q as CFDictionary, &item)
    let attrs = item as? [String: Any]
    check(st == errSecSuccess && attrs?[kSecAttrLabel as String] as? String == "Alice's token" && attrs?[kSecAttrAccount as String] as? String == "alice"
          && attrs?[kSecAttrService as String] as? String == service && attrs?[kSecValueData as String] == nil, "kSecReturnAttributes")
    check(attrs?[kSecAttrAccessGroup as String] as? String == Bundle.main.bundleIdentifier && attrs?[kSecAttrCreationDate as String] is Date
          && attrs?[kSecAttrAccessible as String] as? String == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String), "default access group, dates, accessibility")

    var bob = base
    bob[kSecAttrAccount as String] = "bob"
    bob[kSecValueData as String] = Data([0, 1, 2])
    check(SecItemAdd(bob as CFDictionary, nil) == errSecSuccess, "second account")
    var all = base
    all[kSecMatchLimit as String] = kSecMatchLimitAll
    all[kSecReturnAttributes as String] = true
    all[kSecReturnData as String] = true
    st = SecItemCopyMatching(all as CFDictionary, &item)
    let list = item as? [[String: Any]] ?? []
    let accounts = list.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    check(st == errSecSuccess && accounts == ["alice", "bob"] && list.allSatisfy { $0[kSecValueData as String] is Data }, "kSecMatchLimitAll returns every item (\(accounts))")

    var upd = base
    upd[kSecAttrAccount as String] = "alice"
    st = SecItemUpdate(upd as CFDictionary, [kSecValueData as String: Data("n3w".utf8)] as CFDictionary)
    q[kSecReturnAttributes as String] = nil
    q[kSecReturnData as String] = true
    _ = SecItemCopyMatching(q as CFDictionary, &item)
    check(st == errSecSuccess && (item as? Data) == Data("n3w".utf8), "SecItemUpdate changes the data")
    st = SecItemUpdate(upd as CFDictionary, [kSecAttrAccount as String: "bob"] as CFDictionary)
    check(st == errSecDuplicateItem, "SecItemUpdate onto an existing primary key -> errSecDuplicateItem")
    var missing = base
    missing[kSecAttrAccount as String] = "carol"
    check(SecItemUpdate(missing as CFDictionary, [kSecAttrLabel as String: "x"] as CFDictionary) == errSecItemNotFound, "SecItemUpdate on nothing -> errSecItemNotFound")

    // internet passwords have their own primary key
    let inet: [String: Any] = [kSecClass as String: kSecClassInternetPassword, kSecAttrServer as String: "example.com",
                               kSecAttrProtocol as String: kSecAttrProtocolHTTPS, kSecAttrPort as String: 443,
                               kSecAttrAccount as String: "alice", kSecValueData as String: Data("pw".utf8)]
    _ = SecItemDelete([kSecClass as String: kSecClassInternetPassword, kSecAttrServer as String: "example.com"] as CFDictionary)
    check(SecItemAdd(inet as CFDictionary, nil) == errSecSuccess, "SecItemAdd internet password")
    var iq: [String: Any] = [kSecClass as String: kSecClassInternetPassword, kSecAttrServer as String: "example.com", kSecAttrPort as String: 443,
                             kSecReturnAttributes as String: true]
    st = SecItemCopyMatching(iq as CFDictionary, &item)
    check(st == errSecSuccess && (item as? [String: Any])?[kSecAttrPort as String] as? Int == 443, "internet password query by server + port")
    iq[kSecAttrPort as String] = 8443
    check(SecItemCopyMatching(iq as CFDictionary, &item) == errSecItemNotFound && item == nil, "no match -> errSecItemNotFound, result nil")

    // persistent references
    var pr = base
    pr[kSecAttrAccount as String] = "bob"
    pr[kSecReturnPersistentRef as String] = true
    _ = SecItemCopyMatching(pr as CFDictionary, &item)
    if let ref = item as? Data {
        let byRef: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecValuePersistentRef as String: ref, kSecReturnData as String: true]
        st = SecItemCopyMatching(byRef as CFDictionary, &item)
        check(st == errSecSuccess && (item as? Data) == Data([0, 1, 2]), "kSecReturnPersistentRef / kSecValuePersistentRef")
    } else { check(false, "kSecReturnPersistentRef") }

    // persisted per access group under the device data directory
    let data = String(cString: getenv("ISIM_DATA") ?? strdup(NSHomeDirectory()))
    let file = data + "/Library/Keychains/" + (Bundle.main.bundleIdentifier ?? "") + ".keychain"
    var sb = stat()
    check(stat(file, &sb) == 0 && sb.st_mode & 0o777 == 0o600, "stored in $ISIM_DATA/Library/Keychains/<group>.keychain (0600)")
    var grp = add
    grp[kSecAttrAccessGroup as String] = "group.dev.isim.shared"
    _ = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccessGroup as String: "group.dev.isim.shared"] as CFDictionary)
    check(SecItemAdd(grp as CFDictionary, nil) == errSecSuccess, "same item in another access group is not a duplicate")
    var gq = base
    gq[kSecAttrAccessGroup as String] = "group.dev.isim.shared"
    gq[kSecMatchLimit as String] = kSecMatchLimitAll
    gq[kSecReturnAttributes as String] = true
    st = SecItemCopyMatching(gq as CFDictionary, &item)
    check(st == errSecSuccess && (item as? [[String: Any]])?.count == 1, "query restricted to an access group")

    check(SecItemDelete(missing as CFDictionary) == errSecItemNotFound, "SecItemDelete on nothing -> errSecItemNotFound")
    check(SecItemDelete(base as CFDictionary) == errSecSuccess, "SecItemDelete removes all matching items")
    check(SecItemCopyMatching(all as CFDictionary, &item) == errSecItemNotFound, "items are gone after delete")
    _ = SecItemDelete(gq as CFDictionary)
    check(SecItemAdd([kSecValueData as String: Data()] as CFDictionary, nil) == errSecParam, "missing kSecClass -> errSecParam")
    check(SecItemAdd([kSecClass as String: kSecClassKey] as CFDictionary, nil) == errSecParam, "a key item without kSecValueRef or kSecValueData -> errSecParam")
    check((SecCopyErrorMessageString(errSecItemNotFound, nil) as String?) == "The specified item could not be found in the keychain.", "SecCopyErrorMessageString")
    var bytes = [UInt8](repeating: 0, count: 16)
    check(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess && bytes != [UInt8](repeating: 0, count: 16), "SecRandomCopyBytes")
}
