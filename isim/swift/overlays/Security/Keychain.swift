// isim Security: the keychain store behind SecItem*. See Security.swift for the storage location and limits.
import Foundation

enum _KCValue: Codable, Equatable {
    case string(String), data([UInt8]), int(Int), double(Double), bool(Bool), date(Double)

    /// a Swift/Foundation value from a query or attribute dictionary
    init?(_ v: Any, key: String) {
        if _Keychain.boolKeys.contains(key) {
            if let b = v as? Bool { self = .bool(b); return }
            if let n = v as? NSNumber { self = .bool(n.boolValue); return }
            if let s = v as? String { self = .string(s); return }        // kSecAttrSynchronizableAny
            return nil
        }
        if let s = v as? String { self = .string(s) }
        else if let d = v as? Data { self = .data(Array(d)) }
        else if let d = v as? [UInt8] { self = .data(d) }
        else if let d = v as? Date { self = .date(d.timeIntervalSince1970) }
        else if let i = v as? Int { self = .int(i) }
        else if let d = v as? Double { self = d == d.rounded() && abs(d) < 1e15 ? .int(Int(d)) : .double(d) }
        else if let b = v as? Bool { self = .bool(b) }
        else if let n = v as? NSNumber { self = .int(Int(n.intValue)) }
        else { return nil }
    }
    var any: Any {
        switch self {
        case .string(let s): return s
        case .data(let d): return Data(d)
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .date(let t): return Date(timeIntervalSince1970: t)
        }
    }
    func matches(_ other: _KCValue, caseInsensitive: Bool) -> Bool {
        if caseInsensitive, case .string(let a) = self, case .string(let b) = other { return a.lowercased() == b.lowercased() }
        if case .bool(let a) = self, case .int(let b) = other { return (b != 0) == a }
        if case .int(let a) = self, case .bool(let b) = other { return (a != 0) == b }
        return self == other
    }
}

struct _KCItem: Codable {
    var id: String
    var cls: String
    var attrs: [String: _KCValue]
    var data: [UInt8]?
}
struct _KCFile: Codable {
    var items: [_KCItem] = []
    var groups: [String]? = nil        // (default group only) other access groups this app has stored items in
}

final class _Keychain: @unchecked Sendable {
    static let shared = _Keychain()
    static let boolKeys: Set<String> = ["sync", "invi", "nega", "nleg"]
    static let primaryKeys: [String: [String]] = [
        "genp": ["agrp", "svce", "acct", "sync"],
        "inet": ["agrp", "srvr", "ptcl", "atyp", "port", "path", "acct", "sdmn", "sync"],
        "keys": ["agrp", "kcls", "klbl", "atag", "type", "bsiz", "sync"],
        "cert": ["agrp", "ctyp", "issr", "slnr", "sync"],
        "idnt": ["agrp", "ctyp", "issr", "slnr", "sync"],
    ]
    let lock = NSLock()
    let defaultGroup = Bundle.main.bundleIdentifier ?? "isim.unknown"

    static func dict(_ cf: CFDictionary) -> [String: Any] { (cf as NSDictionary as? [String: Any]) ?? [:] }

    var directory: String {
        let env = getenv("ISIM_DATA").map { String(cString: $0) } ?? ""
        let data = env.isEmpty ? (getenv("HOME").map { String(cString: $0) } ?? "/tmp") + "/.local/share/isim" : env
        return data + "/Library/Keychains"
    }
    func path(_ group: String) -> String {
        directory + "/" + String(group.map { $0 == "/" ? "_" : $0 }) + ".keychain"
    }
    func load(_ group: String) -> _KCFile {
        guard let d = FileManager.default.contents(atPath: path(group)), let f = try? JSONDecoder().decode(_KCFile.self, from: d) else { return _KCFile() }
        return f
    }
    func save(_ file: _KCFile, _ group: String) -> OSStatus {
        mkdir_p(directory)
        guard let d = try? JSONEncoder().encode(file) else { return errSecIO }
        let p = path(group), tmp = p + ".tmp"
        guard let f = fopen(tmp, "wb") else { return errSecIO }
        _ = chmod(tmp, 0o600)
        let ok = d.withUnsafeBytes { fwrite($0.baseAddress, 1, $0.count, f) == $0.count }
        fclose(f)
        guard ok, rename(tmp, p) == 0 else { unlink(tmp); return errSecIO }
        return errSecSuccess
    }
    func mkdir_p(_ p: String) {
        var cur = ""
        for part in p.split(separator: "/") { cur += "/" + part; mkdir(cur, 0o755) }
    }
    /// access groups an app can read without naming one: its default group and groups it stored items in
    func groups() -> [String] { [defaultGroup] + (load(defaultGroup).groups ?? []) }
    func remember(group: String) {
        guard group != defaultGroup else { return }
        var f = load(defaultGroup)
        if !(f.groups ?? []).contains(group) { f.groups = (f.groups ?? []) + [group]; _ = save(f, defaultGroup) }
    }

    // MARK: matching

    func classOf(_ q: [String: Any]) -> (String?, OSStatus) {
        guard let c = q["class"] as? String else { return (nil, errSecParam) }
        switch c {
        case "genp", "inet", "keys": return (c, errSecSuccess)
        case "cert", "idnt": return (c, errSecSuccess)
        default: return (nil, errSecParam)
        }
    }
    func persistentRef(_ group: String, _ item: _KCItem) -> Data { Data("isim-kc:\(group):\(item.id)".utf8) }
    func matches(_ item: _KCItem, group: String, _ q: [String: Any], cls: String) -> Bool {
        guard item.cls == cls else { return false }
        let ci = (q["m_CaseInsensitive"] as? Bool) ?? false
        if let ref = q["v_PersistentRef"] as? Data, ref != persistentRef(group, item) { return false }
        if let ref = q["v_Ref"], let want = _Keychain.refData(ref), want != (item.data ?? []) { return false }
        for (k, v) in q {
            if k == "class" || k.hasPrefix("r_") || k.hasPrefix("m_") || k.hasPrefix("u_") || k.hasPrefix("v_") || k == "nleg" || k == "accc" { continue }
            if k == "sync" {
                if let s = v as? String, s == "syna" { continue }
                let want = (v as? Bool) ?? (v as? NSNumber)?.boolValue ?? false
                if case .bool(let have) = item.attrs["sync"] ?? .bool(false), have != want { return false }
                continue
            }
            if k == "agrp" { continue }   // selected by file
            guard let want = _KCValue(v, key: k), let have = item.attrs[k], have.matches(want, caseInsensitive: ci) else { return false }
        }
        if q["sync"] == nil, case .bool(true) = item.attrs["sync"] ?? .bool(false) { return false }
        return true
    }
    func primaryKey(_ item: _KCItem) -> [String: _KCValue] {
        var key: [String: _KCValue] = [:]
        for k in _Keychain.primaryKeys[item.cls] ?? [] { key[k] = item.attrs[k] ?? (k == "sync" ? .bool(false) : nil) }
        return key
    }
    func searchGroups(_ q: [String: Any]) -> [String] {
        if let g = q["agrp"] as? String { return [g] }
        return groups()
    }

    // MARK: results

    func result(for found: [(String, _KCItem)], _ q: [String: Any], _ out: UnsafeMutablePointer<CFTypeRef?>?) {
        func flag(_ k: String) -> Bool { (q[k] as? Bool) ?? (q[k] as? NSNumber)?.boolValue ?? false }
        let wantData = flag("r_Data"), wantAttrs = flag("r_Attributes"), wantPRef = flag("r_PersistentRef"), wantRef = flag("r_Ref")
        let kinds = [wantData, wantAttrs, wantPRef, wantRef].filter { $0 }.count
        guard kinds > 0, let out else { return }
        func value(_ group: String, _ item: _KCItem) -> Any {
            if kinds == 1 && wantData { return Data(item.data ?? []) }
            if kinds == 1 && wantPRef { return persistentRef(group, item) }
            if kinds == 1 && wantRef { return _Keychain.makeRef(item) ?? NSNull() }
            var d: [String: Any] = ["class": item.cls]
            if wantAttrs { for (k, v) in item.attrs where !k.hasPrefix("_") { d[k] = v.any } }
            if wantData { d["v_Data"] = Data(item.data ?? []) }
            if wantPRef { d["v_PersistentRef"] = persistentRef(group, item) }
            if wantRef, let r = _Keychain.makeRef(item) { d["v_Ref"] = r }
            return d
        }
        if isAll(q) { out.pointee = found.map { value($0.0, $0.1) } as AnyObject }
        else if let first = found.first { out.pointee = value(first.0, first.1) as AnyObject }
    }
    func isAll(_ q: [String: Any]) -> Bool {
        if let s = q["m_Limit"] as? String { return s == "m_LimitAll" }
        if let n = q["m_Limit"] as? Int { return n > 1 }
        return false
    }

    // MARK: operations

    func add(_ a: [String: Any], _ out: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        let (cls, st) = classOf(a)
        guard let cls else { return st }
        var item = _KCItem(id: UUID().uuidString, cls: cls, attrs: [:], data: nil)
        if let v = a["v_Data"] {
            guard let d = v as? Data else { return errSecParam }
            item.data = Array(d)
        }
        if let ref = a["v_Ref"] {
            guard let attrs = _Keychain.refAttributes(ref, cls: cls) else { return errSecParam }
            item.data = attrs.data
            for (k, v) in attrs.attrs where a[k] == nil { item.attrs[k] = v }
        }
        if cls == "keys" || cls == "cert" || cls == "idnt", item.data == nil { return errSecParam }
        for (k, v) in a {
            if k == "class" || k.hasPrefix("r_") || k.hasPrefix("m_") || k.hasPrefix("u_") || k.hasPrefix("v_") || k == "nleg" { continue }
            if k == "accc" {
                guard let ac = v as? SecAccessControl else { return errSecParam }
                item.attrs["pdmn"] = .string(ac.protection); item.attrs["accc"] = .int(Int(ac.flags.rawValue)); continue
            }
            guard let val = _KCValue(v, key: k) else { return errSecParam }
            if k == "sync", case .string = val { return errSecParam }
            item.attrs[k] = val
        }
        let group: String
        if case .string(let g) = item.attrs["agrp"] ?? .string(defaultGroup) { group = g } else { return errSecParam }
        let now = Date().timeIntervalSince1970
        item.attrs["agrp"] = .string(group)
        item.attrs["cdat"] = item.attrs["cdat"] ?? .date(now)
        item.attrs["mdat"] = item.attrs["mdat"] ?? .date(now)
        item.attrs["pdmn"] = item.attrs["pdmn"] ?? .string("ak")
        item.attrs["sync"] = item.attrs["sync"] ?? .bool(false)
        lock.lock(); defer { lock.unlock() }
        var file = load(group)
        let pk = primaryKey(item)
        if file.items.contains(where: { $0.cls == cls && primaryKey($0) == pk }) { return errSecDuplicateItem }
        file.items.append(item)
        let s = save(file, group)
        guard s == errSecSuccess else { return s }
        remember(group: group)
        result(for: [(group, item)], a, out)
        return errSecSuccess
    }

    func copyMatching(_ q: [String: Any], _ out: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        out?.pointee = nil
        let (cls, st) = classOf(q)
        guard let cls else { return st }
        lock.lock(); defer { lock.unlock() }
        var found: [(String, _KCItem)] = []
        for g in searchGroups(q) { for item in load(g).items where matches(item, group: g, q, cls: cls) { found.append((g, item)) } }
        if let n = q["m_Limit"] as? Int, n > 0 { found = Array(found.prefix(n)) }
        guard !found.isEmpty else { return errSecItemNotFound }
        result(for: found, q, out)
        return errSecSuccess
    }

    func update(_ q: [String: Any], _ changes: [String: Any]) -> OSStatus {
        let (cls, st) = classOf(q)
        guard let cls else { return st }
        if changes["class"] != nil { return errSecParam }
        var newData: [UInt8]?
        if let v = changes["v_Data"] { guard let d = v as? Data else { return errSecParam }; newData = Array(d) }
        var newAttrs: [String: _KCValue] = [:]
        for (k, v) in changes where !(k.hasPrefix("r_") || k.hasPrefix("m_") || k.hasPrefix("u_") || k.hasPrefix("v_") || k == "nleg") {
            if k == "accc", let ac = v as? SecAccessControl { newAttrs["accc"] = .int(Int(ac.flags.rawValue)); newAttrs["pdmn"] = .string(ac.protection); continue }
            guard let val = _KCValue(v, key: k) else { return errSecParam }
            newAttrs[k] = val
        }
        lock.lock(); defer { lock.unlock() }
        var files: [String: _KCFile] = [:]
        var touched = 0
        for g in searchGroups(q) {
            var f = files[g] ?? load(g)
            for i in f.items.indices where matches(f.items[i], group: g, q, cls: cls) {
                var it = f.items[i]
                for (k, v) in newAttrs { it.attrs[k] = v }
                if let newData { it.data = newData }
                it.attrs["mdat"] = .date(Date().timeIntervalSince1970)
                let pk = primaryKey(it)
                if f.items.indices.contains(where: { $0 != i && f.items[$0].cls == cls && primaryKey(f.items[$0]) == pk }) { return errSecDuplicateItem }
                f.items[i] = it; touched += 1
            }
            files[g] = f
        }
        guard touched > 0 else { return errSecItemNotFound }
        // items whose access group changed move to that group's file
        for g in Array(files.keys) {
            guard var f = files[g] else { continue }
            var stay: [_KCItem] = []
            for it in f.items {
                if case .string(let ng) = it.attrs["agrp"] ?? .string(g), ng != g {
                    var dst = files[ng] ?? load(ng)
                    if dst.items.contains(where: { $0.cls == it.cls && primaryKey($0) == primaryKey(it) }) { return errSecDuplicateItem }
                    dst.items.append(it); files[ng] = dst; remember(group: ng)
                } else { stay.append(it) }
            }
            f.items = stay; files[g] = f
        }
        for (g, f) in files { let s = save(f, g); if s != errSecSuccess { return s } }
        return errSecSuccess
    }

    func delete(_ q: [String: Any]) -> OSStatus {
        let (cls, st) = classOf(q)
        guard let cls else { return st }
        lock.lock(); defer { lock.unlock() }
        var removed = 0
        for g in searchGroups(q) {
            var f = load(g)
            let before = f.items.count
            f.items.removeAll { matches($0, group: g, q, cls: cls) }
            if f.items.count != before {
                removed += before - f.items.count
                let s = save(f, g); if s != errSecSuccess { return s }
            }
        }
        return removed > 0 ? errSecSuccess : errSecItemNotFound
    }
}

// MARK: - keys, certificates and identities as keychain items

extension _Keychain {
    /// the stored bytes and attributes for a kSecValueRef
    static func refAttributes(_ ref: Any, cls: String) -> (data: [UInt8], attrs: [String: _KCValue])? {
        if cls == "keys", let key = ref as? SecKey {
            var a: [String: _KCValue] = [
                "kcls": .string(key.isPrivate ? "1" : "0"), "type": .string(key.typeString), "bsiz": .int(key.bits), "esiz": .int(key.bits),
                "klbl": .data(key.applicationLabel), "perm": .bool(true),
            ]
            if let tag = key.attributes["atag"] {
                if let d = tag as? Data { a["atag"] = .data(Array(d)) } else if let s = tag as? String { a["atag"] = .data(Array(s.utf8)) }
            }
            if let l = key.attributes["labl"] as? String { a["labl"] = .string(l) }
            return (key.raw, a)
        }
        return _certificateRefAttributes(ref, cls: cls)
    }
    static func refData(_ ref: Any) -> [UInt8]? {
        if let key = ref as? SecKey { return key.raw }
        if let c = ref as? SecCertificate { return c.der }
        if let i = ref as? SecIdentity { return i.certificate.der }
        return nil
    }
    static func makeRef(_ item: _KCItem) -> AnyObject? {
        if item.cls == "keys", let data = item.data {
            var priv = false, type: Int32 = 0
            if case .string(let c) = item.attrs["kcls"] ?? .string("1") { priv = c == "1" }
            if case .string(let t) = item.attrs["type"] ?? .string("42") { type = t == "73" ? 1 : 0 }
            guard let key = SecKey.load(type: type, isPrivate: priv, raw: data) else { return nil }
            if case .data(let tag) = item.attrs["atag"] { key.attributes["atag"] = Data(tag) }
            if case .string(let l) = item.attrs["labl"] { key.attributes["labl"] = l }
            key.attributes["perm"] = true
            return key
        }
        return _makeCertificateRef(item)
    }
}
