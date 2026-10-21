// isim PassKit: Wallet passes — PKPass read from a .pkpass archive, PKPassLibrary over isim's own Wallet in the
// device data ($ISIM_DATA/Library/Wallet/Passes, one .pkpass per pass; `isim wallet` lists and edits it), and the
// orders Apple Pay payments add (PKPaymentOrderDetails, $ISIM_DATA/Library/Wallet/Orders). Self-authored, iOS API names.
// Adapted: a pass's manifest hashes are checked and it must be signed, but the signature's chain to Apple's WWDR
// certificate is not (isim has no Apple trust store for passes); the app sees every pass in the Wallet.
import Foundation
import UIKit
import Compression
import CryptoKit

public let PKPassKitErrorDomain = "PKPassKitErrorDomain"

/// An error reading or adding a pass.
public struct PKPassKitError: CustomNSError, Hashable, @unchecked Sendable {
    public enum Code: Int, Sendable, Equatable {
        case unknownError = -1, invalidDataError = 1, unsupportedVersionError, invalidSignature, notEntitledError
    }
    public let _nsError: NSError
    public init(_nsError: NSError) { self._nsError = _nsError }
    public init(_ code: Code, userInfo: [String: Any] = [:]) {
        _nsError = NSError(domain: PKPassKitErrorDomain, code: code.rawValue, userInfo: userInfo)
    }
    init(_ code: Code, _ description: String) { self.init(code, userInfo: [NSLocalizedDescriptionKey: description]) }
    public var code: Code { Code(rawValue: _nsError.code) ?? .unknownError }
    public static var errorDomain: String { PKPassKitErrorDomain }
    public var errorCode: Int { _nsError.code }
    public var errorUserInfo: [String: Any] { _nsError.userInfo }
    public var userInfo: [String: Any] { _nsError.userInfo }
    public var localizedDescription: String { _nsError.localizedDescription }
    public static func == (a: PKPassKitError, b: PKPassKitError) -> Bool { a._nsError.isEqual(b._nsError) }
    public func hash(into h: inout Hasher) { h.combine(_nsError.code) }
    public static var unknownError: Code { .unknownError }
    public static var invalidDataError: Code { .invalidDataError }
    public static var unsupportedVersionError: Code { .unsupportedVersionError }
    public static var invalidSignature: Code { .invalidSignature }
    public static var notEntitledError: Code { .notEntitledError }
}

// MARK: - ZIP archives (.pkpass, .pkpasses)

enum _PKZip {
    /// the files of a ZIP archive, by path (stored and deflated entries)
    static func files(_ d: Data) throws -> [String: Data] {
        let b = [UInt8](d)
        func u16(_ i: Int) -> Int { i + 1 < b.count ? Int(b[i]) | Int(b[i + 1]) << 8 : 0 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        let bad = PKPassKitError(.invalidDataError, "The pass is not a valid archive")
        guard b.count >= 22 else { throw bad }
        var end = -1
        var i = b.count - 22
        while i >= max(0, b.count - 22 - 65_535) { if u32(i) == 0x0605_4b50 { end = i; break }; i -= 1 }
        guard end >= 0 else { throw bad }
        let count = u16(end + 10)
        var p = u32(end + 16)
        var out: [String: Data] = [:]
        for _ in 0..<count {
            guard p + 46 <= b.count, u32(p) == 0x0201_4b50 else { throw bad }
            let method = u16(p + 10), csize = u32(p + 20), usize = u32(p + 24)
            let nlen = u16(p + 28), elen = u16(p + 30), clen = u16(p + 32), local = u32(p + 42)
            guard p + 46 + nlen <= b.count, let name = String(bytes: b[(p + 46)..<(p + 46 + nlen)], encoding: .utf8) else { throw bad }
            p += 46 + nlen + elen + clen
            if name.hasSuffix("/") || name.hasPrefix("__MACOSX/") { continue }
            guard local + 30 <= b.count, u32(local) == 0x0403_4b50 else { throw bad }
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            guard start + csize <= b.count else { throw bad }
            let raw = Data(b[start..<(start + csize)])
            switch method {
            case 0: out[name] = raw
            case 8: out[name] = try inflate(raw, usize, bad)
            default: throw bad
            }
        }
        return out
    }
    static func inflate(_ src: Data, _ size: Int, _ bad: Error) throws -> Data {
        if size == 0 { return Data() }
        var dst = [UInt8](repeating: 0, count: size)
        let n = src.withUnsafeBytes { s in
            compression_decode_buffer(&dst, size, s.bindMemory(to: UInt8.self).baseAddress!, src.count, nil, COMPRESSION_ZLIB)
        }
        guard n == size else { throw bad }
        return Data(dst)
    }
}

// MARK: - Passes

/// The base class of PassKit's pass objects.
@objc(PKObject) open class PKObject: NSObject {}

public enum PKPassType: UInt, Sendable {
    case barcode = 0, secureElement = 1, any = 0xFFFF_FFFF
    @available(*, deprecated, renamed: "secureElement") public static var payment: PKPassType { .secureElement }
}

/// A date or interval when a pass is relevant (pass.json "relevantDates", iOS 18).
@objc(PKPassRelevantDate) open class PKPassRelevantDate: NSObject, @unchecked Sendable {
    @objc open internal(set) var date: Date?
    @objc open internal(set) var interval: DateInterval?
    @objc init(date: Date?, interval: DateInterval?) { self.date = date; self.interval = interval; super.init() }
}

/// A Wallet pass: a boarding pass, coupon, event ticket, store card or generic pass, read from its .pkpass archive.
@objc(PKPass) open class PKPass: PKObject, @unchecked Sendable {
    @objc let archive: Data
    @objc let files: [String: Data]
    @objc let json: [String: Any]
    @objc let strings: [String: String]

    /// reads a .pkpass archive: pass.json, its images and localizations; the manifest must list every file with its
    /// SHA-1 and the archive must have a signature (its certificate chain is not checked)
    @objc public init(data: Data) throws {
        let files = try _PKZip.files(data)
        guard let pj = files["pass.json"], let json = (try? JSONSerialization.jsonObject(with: pj)) as? [String: Any] else {
            throw PKPassKitError(.invalidDataError, "The pass has no valid pass.json")
        }
        guard (json["formatVersion"] as? Int) == 1 else { throw PKPassKitError(.unsupportedVersionError, "The pass's formatVersion is not 1") }
        for key in ["passTypeIdentifier", "serialNumber", "teamIdentifier", "organizationName", "description"] {
            guard let v = json[key] as? String, !v.isEmpty else { throw PKPassKitError(.invalidDataError, "The pass has no \(key)") }
        }
        guard _PKPassStyle.allCases.contains(where: { json[$0.rawValue] is [String: Any] }) else {
            throw PKPassKitError(.invalidDataError, "The pass has no style (boardingPass, coupon, eventTicket, generic or storeCard)")
        }
        guard files["icon.png"] != nil || files["icon@2x.png"] != nil || files["icon@3x.png"] != nil else {
            throw PKPassKitError(.invalidDataError, "The pass has no icon")
        }
        guard let md = files["manifest.json"], let manifest = (try? JSONSerialization.jsonObject(with: md)) as? [String: String] else {
            throw PKPassKitError(.invalidSignature, "The pass has no manifest")
        }
        for (name, content) in files where name != "manifest.json" && name != "signature" {
            let hash = Insecure.SHA1.hash(data: content).map { String(format: "%02x", $0) }.joined()
            guard manifest[name]?.lowercased() == hash else { throw PKPassKitError(.invalidSignature, "The manifest's hash of \(name) does not match") }
        }
        guard manifest.keys.allSatisfy({ files[$0] != nil }) else { throw PKPassKitError(.invalidSignature, "The manifest lists files the pass does not have") }
        guard let sig = files["signature"], !sig.isEmpty else { throw PKPassKitError(.invalidSignature, "The pass is not signed") }
        archive = data; self.files = files; self.json = json
        strings = PKPass.localization(files)
        super.init()
    }

    /// the pass.strings of the preferred language that the pass has (else English, else none)
    @objc static func localization(_ files: [String: Data]) -> [String: String] {
        let langs = Locale.preferredLanguages.flatMap { [$0, String($0.prefix(while: { $0 != "-" && $0 != "_" }))] } + ["en", "Base"]
        guard let lang = langs.first(where: { files["\($0).lproj/pass.strings"] != nil }), let d = files["\(lang).lproj/pass.strings"] else { return [:] }
        let text: String
        if d.starts(with: [0xFF, 0xFE]) || d.starts(with: [0xFE, 0xFF]) { text = String(data: d, encoding: .utf16) ?? "" } else { text = String(data: d, encoding: .utf8) ?? "" }
        var out: [String: String] = [:]
        let re = try! NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;"#)
        func unescape(_ s: String) -> String { s.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\\\", with: "\\") }
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out[unescape(ns.substring(with: m.range(at: 1)))] = unescape(ns.substring(with: m.range(at: 2)))
        }
        return out
    }

    @objc func string(_ key: String) -> String? { (json[key] as? String).map { strings[$0] ?? $0 } }
    @objc func date(_ s: Any?) -> Date? {
        guard let s = s as? String else { return nil }
        let f = ISO8601DateFormatter()
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
    @objc var key: String { "\(passTypeIdentifier)|\(serialNumber)" }

    open var passType: PKPassType { .barcode }
    @objc open var passTypeIdentifier: String { json["passTypeIdentifier"] as? String ?? "" }
    @objc open var serialNumber: String { json["serialNumber"] as? String ?? "" }
    @objc open var organizationName: String { string("organizationName") ?? "" }
    /// the pass's name in Wallet: its organization's (iOS shows the app's for some passes)
    @objc open var localizedName: String { organizationName }
    @objc open var localizedDescription: String { string("description") ?? "" }
    @objc open var webServiceURL: URL? { (json["webServiceURL"] as? String).flatMap(URL.init(string:)) }
    @objc open var authenticationToken: String? { json["authenticationToken"] as? String }
    @objc open var userInfo: [AnyHashable: Any]? { json["userInfo"] as? [String: Any] }
    @objc open var deviceName: String { UIDevice.current.name }
    @objc open var isRemotePass: Bool { false }
    /// opens the pass in Wallet (isim has no Wallet app: the URL names the pass)
    @objc open var passURL: URL? { URL(string: "shoebox://card/\(passTypeIdentifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")/\(serialNumber.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")") }
    @objc open var icon: UIImage {
        let scale = UIScreen.main.scale
        let order = scale >= 3 ? ["icon@3x.png", "icon@2x.png", "icon.png"] : scale >= 2 ? ["icon@2x.png", "icon@3x.png", "icon.png"] : ["icon.png", "icon@2x.png", "icon@3x.png"]
        for n in order { if let d = files[n], let i = UIImage(data: d, scale: n.contains("@3x") ? 3 : n.contains("@2x") ? 2 : 1) { return i } }
        return UIImage()
    }
    @available(*, deprecated, message: "Use relevantDates")
    @objc open var relevantDate: Date? { date(json["relevantDate"]) ?? relevantDates.first?.date ?? relevantDates.first?.interval?.start }
    @objc open var relevantDates: [PKPassRelevantDate] {
        if let list = json["relevantDates"] as? [[String: Any]] {
            return list.compactMap { e -> PKPassRelevantDate? in
                if let d = date(e["date"]) { return PKPassRelevantDate(date: d, interval: nil) }
                if let s = date(e["startDate"]), let t = date(e["endDate"]), t >= s { return PKPassRelevantDate(date: nil, interval: DateInterval(start: s, end: t)) }
                return nil
            }
        }
        return date(json["relevantDate"]).map { [PKPassRelevantDate(date: $0, interval: nil)] } ?? []
    }

    /// a field's value (localized), by its key, from any of the pass's field lists
    @objc open func localizedValue(forFieldKey key: String) -> Any? {
        guard let f = fields.first(where: { $0.key == key }) else { return nil }
        if f.raw["dateStyle"] != nil || f.raw["timeStyle"] != nil, let d = date(f.raw["value"]) { return d }
        if let s = f.raw["value"] as? String { return strings[s] ?? s }
        return f.raw["value"]
    }

    var style: _PKPassStyle { _PKPassStyle.allCases.first { json[$0.rawValue] is [String: Any] } ?? .generic }
    @objc var styleDictionary: [String: Any] { json[style.rawValue] as? [String: Any] ?? [:] }
    struct Field { let key: String, label: String?, value: String, raw: [String: Any] }
    func fields(_ list: String) -> [Field] {
        (styleDictionary[list] as? [[String: Any]] ?? []).compactMap { f -> Field? in
            guard let key = f["key"] as? String, let v = f["value"] else { return nil }
            let value: String
            if f["dateStyle"] != nil || f["timeStyle"] != nil, let d = date(v) {
                let df = DateFormatter()
                df.dateStyle = f["dateStyle"] == nil ? .none : .medium; df.timeStyle = f["timeStyle"] == nil ? .none : .short
                value = df.string(from: d)
            } else if let s = v as? String { value = strings[s] ?? s } else if let n = v as? NSNumber, let c = f["currencyCode"] as? String {
                let nf = NumberFormatter(); nf.numberStyle = .currency; nf.currencyCode = c
                value = nf.string(from: n) ?? n.stringValue
            } else { value = "\(v)" }
            return Field(key: key, label: (f["label"] as? String).map { strings[$0] ?? $0 }, value: value, raw: f)
        }
    }
    var fields: [Field] { ["headerFields", "primaryFields", "secondaryFields", "auxiliaryFields", "backFields"].flatMap(fields) }
    var barcode: (format: String, message: String, alt: String?)? {
        let b = (json["barcodes"] as? [[String: Any]])?.first ?? (json["barcode"] as? [String: Any])
        guard let b, let format = b["format"] as? String, let message = b["message"] as? String else { return nil }
        return (format, message, b["altText"] as? String)
    }
    @objc func color(_ key: String) -> UIColor? {
        guard let s = json[key] as? String else { return nil }
        let n = s.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).compactMap(Double.init)
        guard n.count >= 3 else { return nil }
        return UIColor(red: n[0] / 255, green: n[1] / 255, blue: n[2] / 255, alpha: 1)
    }
    @objc var logo: UIImage? {
        for n in ["logo@3x.png", "logo@2x.png", "logo.png"] { if let d = files[n], let i = UIImage(data: d, scale: n.contains("@3x") ? 3 : n.contains("@2x") ? 2 : 1) { return i } }
        return nil
    }
    @objc open override var description: String { "<PKPass \(passTypeIdentifier) \(serialNumber) \(style.rawValue)>" }
    @objc open override func isEqual(_ object: Any?) -> Bool { (object as? PKPass).map { $0.key == key } ?? false }
    @objc open override var hash: Int { key.hashValue }
}

enum _PKPassStyle: String, CaseIterable { case boardingPass, coupon, eventTicket, generic, storeCard }

// MARK: - The library

public enum PKPassLibraryAddPassesStatus: Int, Sendable {
    case didAddPasses = 0, shouldReviewPasses, didCancelAddPasses
}

public struct PKPassLibraryNotificationName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let PKPassLibraryDidChange = PKPassLibraryNotificationName("PKPassLibraryDidChangeNotification")
    public static let PKPassLibraryRemotePaymentPassesDidChange = PKPassLibraryNotificationName("PKPassLibraryRemotePaymentPassesDidChangeNotification")
}

public struct PKPassLibraryNotificationKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let addedPassesUserInfoKey = PKPassLibraryNotificationKey(rawValue: "PKPassLibraryAddedPassesUserInfoKey")
    public static let replacementPassesUserInfoKey = PKPassLibraryNotificationKey(rawValue: "PKPassLibraryReplacementPassesUserInfoKey")
    public static let removedPassInfosUserInfoKey = PKPassLibraryNotificationKey(rawValue: "PKPassLibraryRemovedPassInfosUserInfoKey")
    public static let passTypeIdentifierUserInfoKey = PKPassLibraryNotificationKey(rawValue: "PKPassLibraryPassTypeIdentifierUserInfoKey")
    public static let serialNumberUserInfoKey = PKPassLibraryNotificationKey(rawValue: "PKPassLibrarySerialNumberUserInfoKey")
    public static let recoveredPassesUserInfoKey = PKPassLibraryNotificationKey(rawValue: "PKPassLibraryRecoveredPassesUserInfoKey")
}

/// isim's Wallet: the device data's Library/Wallet (passes as .pkpass files, orders as JSON)
enum _PKWalletStore {
    static var root: URL {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? (NSHomeDirectory() as NSString).appendingPathComponent(".local/share/isim")
        return URL(fileURLWithPath: data).appendingPathComponent("Library/Wallet")
    }
    static func dir(_ sub: String) -> URL {
        let d = root.appendingPathComponent(sub)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true, attributes: nil)
        return d
    }
    static func file(_ p: PKPass) -> URL {
        let safe = "\(p.passTypeIdentifier)_\(p.serialNumber)".map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return dir("Passes").appendingPathComponent(String(safe) + ".pkpass")
    }
    static func passes() -> [PKPass] {
        let d = dir("Passes")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? []).filter { $0.hasSuffix(".pkpass") }.sorted()
        return names.compactMap { n in (try? Data(contentsOf: d.appendingPathComponent(n))).flatMap { try? PKPass(data: $0) } }
    }
    static func save(_ p: PKPass) { try? p.archive.write(to: file(p), options: .atomic) }
    static func remove(_ p: PKPass) { try? FileManager.default.removeItem(at: file(p)) }
    static func changed(added: [PKPass] = [], replaced: [PKPass] = [], removed: [PKPass] = []) {
        var info: [AnyHashable: Any] = [:]
        if !added.isEmpty { info[PKPassLibraryNotificationKey.addedPassesUserInfoKey.rawValue] = added }
        if !replaced.isEmpty { info[PKPassLibraryNotificationKey.replacementPassesUserInfoKey.rawValue] = replaced }
        if !removed.isEmpty {
            info[PKPassLibraryNotificationKey.removedPassInfosUserInfoKey.rawValue] = removed.map {
                [PKPassLibraryNotificationKey.passTypeIdentifierUserInfoKey.rawValue: $0.passTypeIdentifier,
                 PKPassLibraryNotificationKey.serialNumberUserInfoKey.rawValue: $0.serialNumber]
            }
        }
        NotificationCenter.default.post(name: Notification.Name(PKPassLibraryNotificationName.PKPassLibraryDidChange.rawValue), object: nil, userInfo: info)
    }
    /// adds or replaces passes; returns those that were new and those that replaced a pass
    static func add(_ list: [PKPass]) -> (added: [PKPass], replaced: [PKPass]) {
        let existing = Set(passes().map(\.key))
        for p in list { save(p) }
        let added = list.filter { !existing.contains($0.key) }, replaced = list.filter { existing.contains($0.key) }
        for p in list { NSLog("isim PassKit: Wallet %@ pass %@ %@ (%@)", existing.contains(p.key) ? "updated" : "added", p.passTypeIdentifier, p.serialNumber, p.organizationName) }
        changed(added: added, replaced: replaced)
        return (added, replaced)
    }

    /// an order an Apple Pay payment added (PKPaymentAuthorizationResult.orderDetails)
    static func addOrder(_ o: PKPaymentOrderDetails, merchant: String, total: String) {
        let safe = "\(o.orderTypeIdentifier)_\(o.orderIdentifier)".map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        let json: [String: Any] = ["orderTypeIdentifier": o.orderTypeIdentifier, "orderIdentifier": o.orderIdentifier,
                                   "webServiceURL": o.webServiceURL.absoluteString, "merchantIdentifier": merchant, "total": total,
                                   "added": ISO8601DateFormatter().string(from: Date())]
        if let d = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .prettyPrinted]) {
            try? d.write(to: dir("Orders").appendingPathComponent(String(safe) + ".json"), options: .atomic)
        }
        NSLog("isim PassKit: Wallet added order %@ %@ (%@)", o.orderTypeIdentifier, o.orderIdentifier, o.webServiceURL.absoluteString)
    }
}

/// The passes in Wallet.
@objc(PKPassLibrary) open class PKPassLibrary: NSObject {
    @objc public override init() { super.init() }

    @objc open class func isPassLibraryAvailable() -> Bool { true }
    @objc open class func isSuppressingAutomaticPassPresentation() -> Bool { false }

    @objc open func passes() -> [PKPass] { _PKWalletStore.passes() }
    open func passes(of passType: PKPassType) -> [PKPass] { passType == .secureElement ? [] : passes() }
    @objc open func pass(withPassTypeIdentifier identifier: String, serialNumber: String) -> PKPass? {
        passes().first { $0.passTypeIdentifier == identifier && $0.serialNumber == serialNumber }
    }
    @objc open func containsPass(_ pass: PKPass) -> Bool { passes().contains { $0.key == pass.key } }
    @objc open func removePass(_ pass: PKPass) {
        guard containsPass(pass) else { return }
        _PKWalletStore.remove(pass)
        NSLog("isim PassKit: Wallet removed pass %@ %@", pass.passTypeIdentifier, pass.serialNumber)
        _PKWalletStore.changed(removed: [pass])
    }
    /// replaces a pass already in Wallet with a newer version of it (false when it is not in Wallet)
    @objc open func replacePass(with pass: PKPass) -> Bool {
        guard containsPass(pass) else { return false }
        _ = _PKWalletStore.add([pass])
        return true
    }

    /// asks the person, as iOS does: Add All, Review (the app then presents PKAddPassesViewController), or Cancel;
    /// passes already in Wallet are updated without asking
    @MainActor open func addPasses(_ passes: [PKPass], withCompletionHandler completion: ((PKPassLibraryAddPassesStatus) -> Void)? = nil) {
        let new = passes.filter { !containsPass($0) }
        if new.isEmpty { _ = _PKWalletStore.add(passes); completion?(.didAddPasses); return }
        guard let top = _PKSheet.topController() else { completion?(.didCancelAddPasses); return }
        let title = new.count == 1 ? "Add “\(new[0].organizationName)” Pass to Wallet?" : "Add \(new.count) Passes to Wallet?"
        let a = UIAlertController(title: title, message: new.map(\.localizedDescription).joined(separator: "\n"), preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in NSLog("isim PassKit: adding passes canceled"); completion?(.didCancelAddPasses) })
        a.addAction(UIAlertAction(title: "Review", style: .default) { _ in completion?(.shouldReviewPasses) })
        a.addAction(UIAlertAction(title: "Add All", style: .default) { _ in _ = _PKWalletStore.add(passes); completion?(.didAddPasses) })
        top.present(a, animated: true, completion: nil)
    }
    @MainActor open func addPasses(_ passes: [PKPass]) async -> PKPassLibraryAddPassesStatus {
        await withCheckedContinuation { k in addPasses(passes, withCompletionHandler: { k.resume(returning: $0) }) }
    }
    @MainActor open func addPasses(data: [Data], completion: @escaping (PKPassLibraryAddPassesStatus) -> Void) {
        let list = data.compactMap { try? PKPass(data: $0) }
        guard !list.isEmpty else { completion(.didCancelAddPasses); return }
        addPasses(list, withCompletionHandler: completion)
    }
    /// a .pkpasses archive: a ZIP of .pkpass files
    @MainActor open func addPasses(fromArchiveData data: Data, completion: @escaping (PKPassLibraryAddPassesStatus) -> Void) {
        addPasses(data: PKPassLibrary.archivePasses(data), completion: completion)
    }
    @MainActor open func addPasses(fromArchiveAt url: URL, completion: @escaping (PKPassLibraryAddPassesStatus) -> Void) {
        addPasses(fromArchiveData: (try? Data(contentsOf: url)) ?? Data(), completion: completion)
    }
    @objc static func archivePasses(_ data: Data) -> [Data] {
        ((try? _PKZip.files(data)) ?? [:]).filter { $0.key.hasSuffix(".pkpass") }.sorted { $0.key < $1.key }.map(\.value)
    }

    /// Apple Pay card setup (Wallet's "Add Card"): isim's Wallet has fixed test cards
    @objc open func openPaymentSetup() { NSLog("isim PassKit: openPaymentSetup: isim's Wallet has fixed test cards (ISIM_APPLE_PAY=0 removes them)") }
    @objc open func openPaymentSetup(merchantIdentifier: String) { openPaymentSetup() }
    @objc open func canAddFelicaPass() -> Bool { false }
}

// MARK: - Orders

/// The Wallet order an Apple Pay payment created (PKPaymentAuthorizationResult.orderDetails).
@objc(PKPaymentOrderDetails) open class PKPaymentOrderDetails: NSObject, @unchecked Sendable {
    @objc open var orderTypeIdentifier: String
    @objc open var orderIdentifier: String
    @objc open var webServiceURL: URL
    @objc open var authenticationToken: String
    @objc public init(orderTypeIdentifier: String, orderIdentifier: String, webServiceURL: URL, authenticationToken: String) {
        self.orderTypeIdentifier = orderTypeIdentifier; self.orderIdentifier = orderIdentifier
        self.webServiceURL = webServiceURL; self.authenticationToken = authenticationToken
        super.init()
    }
}
