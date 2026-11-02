// isim CryptoTokenKit: the token host (issue #743, adapted). For each virtual card in a reader, isim looks for a token
// driver extension (com.apple.ctk-tokens) in this app or in an installed app: the one whose class ID
// (com.apple.ctk.class-id) the card's readers.json entry names in "token", else one whose AIDs (com.apple.ctk.aid, a hex
// string or a list of them) match an applet of the card. It loads the extension in this process (Apple runs it in its
// own), makes its driver (NSExtensionPrincipalClass) and asks it for the card's token (the driver's
// TKSmartCardTokenDriverDelegate, in a session with the card). The token's ID is "<class ID>:<instance ID>".
// _TKSecTokenBackend gives Security the tokens' keychain contents and runs a token key's operations in a TKTokenSession:
// the requested algorithm is converted to the one the session supports, and when the session needs authentication
// (TKError.authenticationNeeded) its TKTokenAuthOperation gets the PIN or password from isim's sheet
// (ISIM_SMARTCARD_PIN answers without it) and the operation runs again.
import Foundation
import Security
import UIKit

@_silgen_name("isim_bundle_register_extension") func _tkRegisterExtensionBundle(_ path: NSString)
@_silgen_name("isim_ui_run_until") func _tkRunUntil(_ done: @escaping @convention(block) () -> Bool)

/// a token driver extension (an .appex in an app's PlugIns)
struct _TKTokenExtension {
    static let point = "com.apple.ctk-tokens"
    let path: String, bundleID: String, executable: String, principal: String?, classID: String, aids: [[UInt8]]

    init?(path: String) {
        guard let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
              let ext = info["NSExtension"] as? [String: Any], ext["NSExtensionPointIdentifier"] as? String == _TKTokenExtension.point else { return nil }
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        self.path = path
        bundleID = info["CFBundleIdentifier"] as? String ?? base
        executable = (path as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? base)
        principal = ext["NSExtensionPrincipalClass"] as? String
        let attrs = ext["NSExtensionAttributes"] as? [String: Any] ?? [:]
        classID = attrs["com.apple.ctk.class-id"] as? String ?? bundleID
        let aid = attrs["com.apple.ctk.aid"]
        aids = ((aid as? [String]) ?? (aid as? String).map { [$0] } ?? []).compactMap { _unhex($0) }.filter { !$0.isEmpty }
    }
    /// the extensions in an app bundle's PlugIns (or the extension itself)
    static func all(in bundle: String) -> [_TKTokenExtension] {
        if bundle.hasSuffix(".appex") { return _TKTokenExtension(path: bundle).map { [$0] } ?? [] }
        let plugins = (bundle as NSString).appendingPathComponent("PlugIns")
        return ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted().filter { $0.hasSuffix(".appex") }
            .compactMap { _TKTokenExtension(path: (plugins as NSString).appendingPathComponent($0)) }
    }
}

var _tkDataDir: String {
    let env = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
    return env.isEmpty ? NSHomeDirectory() + "/.local/share/isim" : env
}

final class _TKTokenHost: @unchecked Sendable {
    static let shared = _TKTokenHost()
    struct Live { let reader: String; let cardKey: String; let token: TKToken; let driver: TKTokenDriver }
    private let lock = NSRecursiveLock()
    private var live: [String: Live] = [:]              // reader name -> its card's token
    private var drivers: [String: TKTokenDriver] = [:]  // class ID -> the loaded driver
    private var failed: Set<String> = []                // card keys no driver made a token for

    /// the token driver extensions of this app (ownOnly) or of every installed app
    func extensions(ownOnly: Bool) -> [_TKTokenExtension] {
        var apps = [Bundle.main.bundlePath]
        if !ownOnly {
            let dir = ProcessInfo.processInfo.environment["ISIM_APPS"] ?? (_tkDataDir as NSString).appendingPathComponent("Applications")
            apps += ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted().filter { $0.hasSuffix(".app") }
                .map { (dir as NSString).appendingPathComponent($0) }
        }
        var seen = Set<String>(), out: [_TKTokenExtension] = []
        for a in apps { for x in _TKTokenExtension.all(in: a) where seen.insert(x.classID).inserted { out.append(x) } }
        return out
    }
    /// the extension for a card, and the AID it matched
    private func driverExtension(_ card: _TKVirtualCard) -> (_TKTokenExtension, [UInt8]?)? {
        let xs = extensions(ownOnly: false)
        func matched(_ x: _TKTokenExtension) -> [UInt8]? {
            for aid in x.aids where card.applets.contains(where: { $0.aid.starts(with: aid) }) { return aid }
            return nil
        }
        if let t = card.token { return xs.first { $0.classID == t }.map { ($0, matched($0)) } }
        for x in xs { if let aid = matched(x) { return (x, aid) } }
        return nil
    }
    private func driver(_ x: _TKTokenExtension) -> TKTokenDriver? {
        if let d = drivers[x.classID] { return d }
        guard let principal = x.principal else { NSLog("isim CryptoTokenKit: the token extension %@ names no NSExtensionPrincipalClass", x.bundleID); return nil }
        if NSClassFromString(principal) == nil {
            guard dlopen(x.executable, RTLD_NOW) != nil else {
                NSLog("isim CryptoTokenKit: cannot load the token extension %@: %s", x.bundleID, dlerror().map { String(cString: $0) } ?? "?"); return nil
            }
            _tkRegisterExtensionBundle(x.path as NSString)
        }
        guard let cls = NSClassFromString(principal) as? TKTokenDriver.Type else {
            let c: AnyClass? = NSClassFromString(principal)
            NSLog("isim CryptoTokenKit: the principal class %@ of %@ is not a TKTokenDriver (%@, super %@)", principal, x.bundleID,
                  c.map { NSStringFromClass($0) } ?? "missing", c.flatMap { class_getSuperclass($0) }.map { NSStringFromClass($0) } ?? "-"); return nil
        }
        let d = (cls as NSObject.Type).init() as! TKTokenDriver
        d.classID = x.classID
        drivers[x.classID] = d
        NSLog("isim CryptoTokenKit: loaded the token driver %@ (%@)", x.classID, principal)
        return d
    }

    /// the tokens of the inserted cards that have a driver (made when a card arrives, ended when it leaves)
    func tokens() -> [Live] {
        lock.lock(); defer { lock.unlock() }
        _TKReaders.shared.reload()
        var now: [String: Live] = [:]
        for r in _TKReaders.shared.readers {
            guard let key = r.cardKey else { continue }
            if let l = live[r.name], l.cardKey == key { now[r.name] = l; continue }
            guard !failed.contains(key), let card = _TKReaders.shared.card(r.name), let (x, aid) = driverExtension(card),
                  let d = driver(x) else { continue }
            guard let sd = d as? TKSmartCardTokenDriver, let delegate = d.delegate as? TKSmartCardTokenDriverDelegate,
                  let sc = TKSmartCardSlot(name: r.name).makeSmartCard() else {
                NSLog("isim CryptoTokenKit: the driver %@ cannot make smart card tokens", x.classID); failed.insert(key); continue
            }
            do {
                let token = try sc.withSession { try delegate.tokenDriver(sd, createTokenFor: sc, aid: aid.map { Data($0) }) }
                now[r.name] = Live(reader: r.name, cardKey: key, token: token, driver: d)
                NSLog("isim CryptoTokenKit: token %@ in %@ (%d keychain items)", token.tokenID, r.name, token.keychainContents?.items.count ?? 0)
            } catch {
                NSLog("isim CryptoTokenKit: the driver %@ made no token for the card in %@: %@", x.classID, r.name, "\(error)")
                failed.insert(key)
            }
        }
        for (reader, l) in live where now[reader]?.token !== l.token { l.driver.delegate?.tokenDriver?(l.driver, terminateToken: l.token) }
        live = now
        return now.values.sorted { $0.reader < $1.reader }
    }
    func token(_ tokenID: String) -> TKToken? { tokens().first { $0.token.tokenID == tokenID }?.token }
}


/// what the token configurations and the registered tokens are kept in ($ISIM_DATA/Library/isim/SmartCards/tokens.json)
enum _TKTokenConfigStore {
    static let lock = NSLock()
    static var path: String { _tkDataDir + "/Library/isim/SmartCards/tokens.json" }
    static func read() -> [String: Any] {
        guard let d = FileManager.default.contents(atPath: path), let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return [:] }
        return j
    }
    static func write(_ j: [String: Any]) {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let d = try? JSONSerialization.data(withJSONObject: j, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: URL(fileURLWithPath: path)) }
    }
    static func update(_ change: (inout [String: Any]) -> Void) { lock.lock(); var j = read(); change(&j); write(j); lock.unlock() }
    static func configs(_ classID: String) -> [String: String] { ((read()["configurations"] as? [String: Any])?[classID] as? [String: String]) ?? [:] }
    static func instances(_ classID: String) -> [String] { configs(classID).keys.sorted() }
    static func add(_ classID: String, _ instanceID: String) {
        update { j in
            var all = j["configurations"] as? [String: Any] ?? [:], c = all[classID] as? [String: String] ?? [:]
            if c[instanceID] == nil { c[instanceID] = "" }
            all[classID] = c; j["configurations"] = all
        }
    }
    static func remove(_ classID: String, _ instanceID: String) {
        update { j in
            var all = j["configurations"] as? [String: Any] ?? [:], c = all[classID] as? [String: String] ?? [:]
            c[instanceID] = nil; all[classID] = c; j["configurations"] = all
        }
    }
    static func data(_ classID: String, _ instanceID: String) -> Data? { configs(classID)[instanceID].flatMap { $0.isEmpty ? nil : Data(base64Encoded: $0) } }
    static func setData(_ classID: String, _ instanceID: String, _ d: Data?) {
        update { j in
            var all = j["configurations"] as? [String: Any] ?? [:], c = all[classID] as? [String: String] ?? [:]
            c[instanceID] = d?.base64EncodedString() ?? ""; all[classID] = c; j["configurations"] = all
        }
    }
    static func registered() -> [String] { (read()["registered"] as? [String] ?? []).sorted() }
    static func register(_ tokenID: String, _ on: Bool) {
        update { j in
            var r = Set(j["registered"] as? [String] ?? [])
            if on { r.insert(tokenID) } else { r.remove(tokenID) }
            j["registered"] = r.sorted()
        }
    }
}

// MARK: - Security's token backend

@objc(_TKSecTokenBackend) final class _TKSecTokenBackend: NSObject, _SecTokenBackend, @unchecked Sendable {
    override init() { super.init(); _secTokenBackend = self }

    func _tokenItems() -> [(cls: String, tokenID: String, index: Int, attributes: [String: Any], data: Data)] {
        var out: [(cls: String, tokenID: String, index: Int, attributes: [String: Any], data: Data)] = []
        for l in _TKTokenHost.shared.tokens() {
            for (i, item) in (l.token.keychainContents?.items ?? []).enumerated() {
                var a: [String: Any] = [:]
                if let label = item.label { a["labl"] = label }
                if let k = item as? TKTokenKeychainKey, let pub = k.publicKeyData {
                    a["type"] = k.keyType; a["bsiz"] = k.keySizeInBits; a["esiz"] = k.keySizeInBits
                    if let tag = k.applicationTag { a["atag"] = tag }
                    if let h = k.publicKeyHash { a["klbl"] = h }
                    a["sign"] = k.canSign; a["decr"] = k.canDecrypt; a["drve"] = k.canPerformKeyExchange
                    out.append(("keys", l.token.tokenID, i, a, pub))
                } else if let c = item as? TKTokenKeychainCertificate, !c.data.isEmpty {
                    out.append(("cert", l.token.tokenID, i, a, c.data))
                }
            }
        }
        return out
    }

    func _tokenOperation(_ op: Int, tokenID: String, index: Int, algorithm: String, input: Data, publicKey: Data?,
                         parameters: [String: Any]) throws -> (Data, Bool) {
        guard let token = _TKTokenHost.shared.token(tokenID) else { throw _tkError(.tokenNotFound, "the token \(tokenID) is not inserted") }
        let items = token.keychainContents?.items ?? []
        guard index < items.count, let key = items[index] as? TKTokenKeychainKey else { throw _tkError(.objectNotFound, "the token's key is gone") }
        let o = try _TKTokenOperationRun(token: token, key: key, op: op, algorithm: algorithm, input: input, publicKey: publicKey, parameters: parameters)
        defer { o.end() }
        let result: Data
        if let card = (token as? TKSmartCardToken)?.smartCard { result = try card.withSession { try o.attempt() } }
        else { result = try o.attempt() }
        return (result, o.plain)
    }
}

/// TKTokenSessionDelegate's throwing methods as required ones (same selectors)
@objc protocol _TKSessionMethods: NSObjectProtocol {
    @objc(tokenSession:signData:usingKey:algorithm:error:) func sign(_ s: TKTokenSession, data: Data, key: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data
    @objc(tokenSession:decryptData:usingKey:algorithm:error:) func decrypt(_ s: TKTokenSession, data: Data, key: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data
    @objc(tokenSession:performKeyExchangeWithPublicKey:usingKey:algorithm:parameters:error:)
    func keyExchange(_ s: TKTokenSession, publicKey: Data, key: Any, algorithm: TKTokenKeyAlgorithm, parameters: TKTokenKeyExchangeParameters) throws -> Data
    @objc(tokenSession:beginAuthForOperation:constraint:error:)
    func beginAuth(_ s: TKTokenSession, operation: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation
}

/// one operation of a token key in a new token session
final class _TKTokenOperationRun {
    let token: TKToken, key: TKTokenKeychainKey, op: Int
    let tokenDelegate: TKTokenDelegate, session: TKTokenSession, delegate: TKTokenSessionDelegate
    let operation: TKTokenOperation, alg: TKTokenKeyAlgorithm
    var data: Data
    let publicKey: Data?, parameters: [String: Any]
    var plain = false

    init(token: TKToken, key: TKTokenKeychainKey, op: Int, algorithm: String, input: Data, publicKey: Data?, parameters: [String: Any]) throws {
        self.token = token; self.key = key; self.op = op; self.publicKey = publicKey; self.parameters = parameters
        guard let td = token.delegate else { throw _tkError(.notImplemented, "the token has no delegate") }
        tokenDelegate = td
        operation = op == 2 ? .signData : op == 3 ? .decryptData : .performKeyExchange
        let allowed = op == 2 ? key.canSign : op == 3 ? key.canDecrypt : key.canPerformKeyExchange
        guard allowed else { throw _tkError(.notImplemented, "the token's key cannot be used for this operation") }
        session = try td.createSession(token)
        guard let d = session.delegate else { td.token?(token, terminateSession: session); throw _tkError(.notImplemented, "the token session has no delegate") }
        delegate = d
        let requested = SecKeyAlgorithm(rawValue: algorithm as CFString)
        alg = TKTokenKeyAlgorithm(requested)
        data = input
        if d.tokenSession?(session, supports: operation, keyObjectID: key.objectID, algorithm: alg) == false {
            td.token?(token, terminateSession: session)
            throw _tkError(.notImplemented, "the token does not support \(algorithm)")
        }
        if let accepted = alg.accepted {
            if op == 4 { plain = (accepted.rawValue as String) != algorithm }
            else { data = TKTokenKeyAlgorithm.convert(requested, to: accepted, input) ?? input }
        }
    }
    func end() { tokenDelegate.token?(token, terminateSession: session) }

    /// the delegate's methods through _TKSessionMethods (calling the optional throwing requirements directly crashes
    /// Swift 6.2's IR generation); nil when the delegate does not implement the method
    private func implemented(_ sel: Selector) -> _TKSessionMethods? {
        delegate.responds(to: sel) ? unsafeBitCast(delegate as AnyObject, to: _TKSessionMethods.self) : nil
    }
    func run() throws -> Data {
        let r: Data
        switch op {
        case 2:
            guard let m = implemented(#selector(_TKSessionMethods.sign(_:data:key:algorithm:))) else { throw _tkError(.notImplemented, "the token session cannot sign") }
            r = try m.sign(session, data: data, key: key.objectID, algorithm: alg)
        case 3:
            guard let m = implemented(#selector(_TKSessionMethods.decrypt(_:data:key:algorithm:))) else { throw _tkError(.notImplemented, "the token session cannot decrypt") }
            r = try m.decrypt(session, data: data, key: key.objectID, algorithm: alg)
        default:
            guard let m = implemented(#selector(_TKSessionMethods.keyExchange(_:publicKey:key:algorithm:parameters:))) else {
                throw _tkError(.notImplemented, "the token session cannot perform key exchanges")
            }
            let p = TKTokenKeyExchangeParameters(requestedSize: (parameters["requestedSize"] as? Int) ?? 0, sharedInfo: parameters["sharedInfo"] as? Data)
            r = try m.keyExchange(session, publicKey: publicKey ?? Data(), key: key.objectID, algorithm: alg, parameters: p)
        }
        return r
    }
    /// runs the operation; when the token needs authentication, authenticates and runs it again
    func attempt() throws -> Data {
        var needsAuth = false
        do { return try run() } catch {
            let e = error as NSError
            guard e.domain == TKErrorDomain, e.code == TKError.Code.authenticationNeeded.rawValue else { throw error }
            needsAuth = true
        }
        precondition(needsAuth)
        let constraint: Any = key.constraints?[NSNumber(value: operation.rawValue)] ?? true
        guard let m = implemented(#selector(_TKSessionMethods.beginAuth(_:operation:constraint:))) else {
            throw _tkError(.authenticationNeeded, "the token needs authentication but its session has no beginAuth")
        }
        let auth = try m.beginAuth(session, operation: operation, constraint: constraint)
        try _TKTokenAuth.authenticate(auth, card: (token as? TKSmartCardToken)?.smartCard, token: token)
        return try run()
    }
}

/// asks the user for a token's PIN or password (isim's sheet) and finishes the authentication
enum _TKTokenAuth {
    static func authenticate(_ auth: TKTokenAuthOperation, card: TKSmartCard?, token: TKToken) throws {
        if let pin = auth as? TKTokenSmartCardPINAuthOperation {
            if pin.smartCard == nil { pin.smartCard = card }
            guard let answer = ask(pin: true, reader: card?.slot.name ?? token.tokenID) else { throw _tkError(.canceledByUser) }
            pin.pin = answer
        } else if let pw = auth as? TKTokenPasswordAuthOperation {
            guard let answer = ask(pin: false, reader: token.tokenID) else { throw _tkError(.canceledByUser) }
            pw.password = answer
        }
        try auth.finish()
    }
    /// the PIN (or password) the user enters; ISIM_SMARTCARD_PIN answers without the sheet
    static func ask(pin: Bool, reader: String) -> String? {
        if let answer = ProcessInfo.processInfo.environment["ISIM_SMARTCARD_PIN"] { return answer }
        final class Box: @unchecked Sendable { var result: String?; var done = false }
        let box = Box()
        let show = {
            guard let top = _tkTopController() else { box.done = true; return }
            let a = UIAlertController(title: pin ? "Enter PIN" : "Enter Password",
                                      message: "\(reader) asks for the smart card's \(pin ? "PIN" : "password").", preferredStyle: .alert)
            a.addTextField { f in
                f.placeholder = pin ? "PIN" : "Password"; f.isSecureTextEntry = true
                f.keyboardType = pin ? .numberPad : .asciiCapable
                f.accessibilityIdentifier = "isim-smartcard-pin-0"
            }
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in box.done = true })
            a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in box.result = a?.textFields?.first?.text ?? ""; box.done = true })
            a.view.accessibilityIdentifier = "isim-smartcard-pin"
            top.present(a, animated: true)
            NSLog("isim CryptoTokenKit: PIN sheet for the token in %@", reader)
        }
        if Thread.isMainThread {                        // the UI keeps running in a nested loop until the sheet is answered
            show()
            _tkRunUntil { box.done }
        } else {
            DispatchQueue.main.async(execute: show)
            while !box.done { usleep(20_000) }
        }
        return box.result
    }
}
