// isim CoreSpotlight: Spotlight asking the app (adapted).
// - CSSearchableIndexDelegate: Spotlight asks the app to reindex all its items, or the ones with given identifiers, and
//   for items by identifier. The home screen sends `isim spotlight reindex|items APP` requests to the app's Spotlight
//   index extension (com.apple.spotlight.index, a CSIndexExtensionRequestHandler), or, without one, to the running
//   app's index delegate (a Darwin notification; the request is a plist in <isim data>/Library/Spotlight/Requests).
// - Items indexed with updateListenerOptions .summarization get a textContentSummary (the first sentences of their
//   textContent), and the index delegate hears searchableItemsDidUpdate, like iOS 18's summaries.
// - CSImportExtension (com.apple.spotlight.import): for files of the types the extension declares
//   (CSSupportedContentTypes) in the app's Documents, the home screen runs it and indexes what it fills in.
import Foundation
import UniformTypeIdentifiers

@objc(CSSearchableIndexDelegate) public protocol CSSearchableIndexDelegate: NSObjectProtocol {
    @objc(searchableIndex:reindexAllSearchableItemsWithAcknowledgementHandler:)
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void)
    @objc(searchableIndex:reindexSearchableItemsWithIdentifiers:acknowledgementHandler:)
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void)
    @objc(searchableIndexDidThrottle:) optional func searchableIndexDidThrottle(_ searchableIndex: CSSearchableIndex)
    @objc(searchableIndexDidFinishThrottle:) optional func searchableIndexDidFinishThrottle(_ searchableIndex: CSSearchableIndex)
    @objc(dataForSearchableIndex:itemIdentifier:typeIdentifier:error:)
    optional func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data
    @objc(fileURLForSearchableIndex:itemIdentifier:typeIdentifier:inPlace:error:)
    optional func fileURL(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace: Bool) throws -> URL
    @available(iOS 18.0, *)
    @objc(searchableItemsDidUpdate:) optional func searchableItemsDidUpdate(_ items: [CSSearchableItem])
    @available(iOS 18.0, *)
    @objc(searchableItemsForIdentifiers:searchableItemsHandler:)
    optional func searchableItems(forIdentifiers identifiers: [String], searchableItemsHandler: @escaping ([CSSearchableItem]) -> Void)
    @available(iOS 18.0, *)
    @objc(searchableItemsForIdentifiers:protectionClass:searchableItemsHandler:)
    optional func searchableItems(forIdentifiers identifiers: [String], protectionClass: FileProtectionType, searchableItemsHandler: @escaping ([CSSearchableItem]) -> Void)
}

/// the principal class of a Spotlight index extension (com.apple.spotlight.index): its CSSearchableIndexDelegate methods
/// answer Spotlight's requests while the app is not running
@objc(CSIndexExtensionRequestHandler) open class CSIndexExtensionRequestHandler: NSObject, NSExtensionRequestHandling, CSSearchableIndexDelegate {
    public override init() { super.init() }
    open func beginRequest(with context: NSExtensionContext) {}
    open func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        acknowledgementHandler()
    }
    open func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        acknowledgementHandler()
    }
}

/// the principal class of a Spotlight import extension (com.apple.spotlight.import): it fills in a file's attributes
@available(iOS 15.0, *)
@objc(CSImportExtension) open class CSImportExtension: NSObject, NSExtensionRequestHandling {
    public override init() { super.init() }
    open func beginRequest(with context: NSExtensionContext) {}
    @objc(updateAttributes:forFileAtURL:error:)
    dynamic open func update(_ attributes: CSSearchableItemAttributeSet, forFileAt contentURL: URL) throws {}
}

// MARK: - Spotlight's requests

enum _CSDelegateListener {
    static var dir: String { (CSSearchableIndex.dataDir as NSString).appendingPathComponent("Library/Spotlight/Requests/" + CSSearchableIndex.bundleID) }
    static let lock = NSLock()
    nonisolated(unsafe) static var indexes: [ObjectIdentifier: () -> CSSearchableIndex?] = [:]
    nonisolated(unsafe) static var token: Int32 = -1

    /// an index with a delegate: Spotlight's requests for the app reach it
    static func listen(_ index: CSSearchableIndex) {
        lock.lock(); defer { lock.unlock() }
        indexes[ObjectIdentifier(index)] = { [weak index] in index }
        guard token < 0 else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        token = 1
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in DispatchQueue.main.async { _CSDelegateListener.serve() } },
                                        ("dev.isim.spotlight." + CSSearchableIndex.bundleID) as CFString, nil, .deliverImmediately)
        NSLog("isim CoreSpotlight: the index delegate listens for Spotlight's requests")
        DispatchQueue.main.async { serve() }                 /* requests made before it listened */
    }
    static func delegateIndex() -> CSSearchableIndex? {
        lock.lock(); defer { lock.unlock() }
        return indexes.values.compactMap { $0() }.first { $0.indexDelegate != nil }
    }
    static func serve() {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasSuffix(".plist") }.sorted()
        for f in files {
            let p = (dir as NSString).appendingPathComponent(f)
            guard let req = NSDictionary(contentsOfFile: p) as? [String: Any], let index = delegateIndex(), let d = index.indexDelegate else { continue }
            try? FileManager.default.removeItem(atPath: p)
            handle(req, delegate: d, index: index) { NSLog("isim CoreSpotlight: the app acknowledged Spotlight's %@ request", req["request"] as? String ?? "?") }
        }
    }
    /// a request: reindex all / some identifiers, or items by identifier (indexed when the delegate returns them)
    static func handle(_ req: [String: Any], delegate d: any CSSearchableIndexDelegate, index: CSSearchableIndex, done: @escaping () -> Void) {
        let ids = req["identifiers"] as? [String] ?? []
        switch req["request"] as? String {
        case "items":
            NSLog("isim CoreSpotlight: Spotlight asks for %ld item(s)", ids.count)
            if #available(iOS 18.0, *), d.responds(to: #selector(CSSearchableIndexDelegate.searchableItems(forIdentifiers:searchableItemsHandler:))) {
                d.searchableItems!(forIdentifiers: ids) { items in index.indexSearchableItems(items) { _ in done() } }
            } else { NSLog("isim CoreSpotlight: the index delegate does not provide items"); done() }
        case "throttle":
            d.searchableIndexDidThrottle?(index); done()
        case "finish-throttle":
            d.searchableIndexDidFinishThrottle?(index); done()
        default:
            if ids.isEmpty {
                NSLog("isim CoreSpotlight: Spotlight asks to reindex all items")
                d.searchableIndex(index, reindexAllSearchableItemsWithAcknowledgementHandler: done)
            } else {
                NSLog("isim CoreSpotlight: Spotlight asks to reindex %@", ids.joined(separator: ", "))
                d.searchableIndex(index, reindexSearchableItemsWithIdentifiers: ids, acknowledgementHandler: done)
            }
        }
    }

    /// iOS 18 summaries: items that asked for them get a textContentSummary, and the index delegate hears of it
    static func itemsIndexed(_ items: [CSSearchableItem], by index: CSSearchableIndex) {
        guard #available(iOS 18.0, *) else { return }
        let wanting = items.filter { $0.updateListenerOptions.contains(.summarization) && ($0.attributeSet.textContent?.isEmpty == false) }
        guard !wanting.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let updated = wanting.map { it -> CSSearchableItem in
                let c = it.copy() as! CSSearchableItem
                c.attributeSet.textContentSummary = summary(it.attributeSet.textContent ?? "")
                return c
            }
            CSSearchableIndex.update { list in
                for u in updated {
                    if let k = list.firstIndex(where: { ($0["kind"] as? String) == "item" && ($0["id"] as? String) == u.uniqueIdentifier }) {
                        var a = list[k]["attributes"] as? [String: Any] ?? [:]
                        a["textContentSummary"] = u.attributeSet.textContentSummary
                        list[k]["attributes"] = a
                    }
                }
            }
            NSLog("isim CoreSpotlight: summarized %ld item(s)", updated.count)
            index.indexDelegate?.searchableItemsDidUpdate?(updated)
        }
    }
    /// the first two sentences (isim's stand-in for Apple Intelligence's summaries)
    static func summary(_ text: String) -> String {
        var out = "", count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { _, _, enclosing, stop in
            out += text[enclosing]; count += 1
            if count == 2 { stop = true }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Spotlight's extensions (helper processes the home screen starts: ISIM_EXTENSION_REQUEST)

/// NSExtensionMain (UIKit) for com.apple.spotlight.index and com.apple.spotlight.import: the principal class answers
/// the request; the result goes to the request's "out" plist
@_cdecl("isim_cs_extension_main")
public func _isim_cs_extension_main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    let ext = Bundle.main.infoDictionary?["NSExtension"] as? [String: Any] ?? [:]
    let name = ext["NSExtensionPrincipalClass"] as? String ?? ""
    guard let rp = ProcessInfo.processInfo.environment["ISIM_EXTENSION_REQUEST"], let req = NSDictionary(contentsOfFile: rp) as? [String: Any] else {
        NSLog("isim CoreSpotlight: the Spotlight extension runs when Spotlight asks (no ISIM_EXTENSION_REQUEST)")
        return 1
    }
    guard let cls = NSClassFromString(name) as? NSObject.Type else {
        NSLog("isim CoreSpotlight: no principal class %@ (NSExtensionPrincipalClass)", name)
        return 1
    }
    let principal = cls.init()
    let out = req["out"] as? String
    func finish(_ result: [String: Any]) -> Never {
        if let out { (result as NSDictionary).write(toFile: out, atomically: true) }
        fflush(nil)
        exit(0)
    }
    if req["request"] as? String == "import" {
        guard #available(iOS 15.0, *), let importer = principal as? CSImportExtension, let path = req["file"] as? String else {
            NSLog("isim CoreSpotlight: %@ is not a CSImportExtension", name)
            finish(["error": "not an import extension"])
        }
        let url = URL(fileURLWithPath: path)
        let type = (req["contentType"] as? String).flatMap { UTType($0) } ?? UTType(filenameExtension: url.pathExtension) ?? .data
        let attrs = CSSearchableItemAttributeSet(contentType: type)
        do {
            try importer.update(attrs, forFileAt: url)
            NSLog("isim CoreSpotlight: imported %@ (%@)", url.lastPathComponent, type.identifier)
            finish(["attributes": attrs._isimPlist])
        } catch {
            NSLog("isim CoreSpotlight: the import extension could not import %@: %@", url.lastPathComponent, "\(error)")
            finish(["error": "\(error)"])
        }
    }
    guard let delegate = principal as? any CSSearchableIndexDelegate else {
        NSLog("isim CoreSpotlight: %@ is not a CSSearchableIndexDelegate", name)
        return 1
    }
    NSLog("isim CoreSpotlight: Spotlight index extension for %@", CSSearchableIndex.bundleID)
    _CSDelegateListener.handle(req, delegate: delegate, index: CSSearchableIndex.default()) {
        NSLog("isim CoreSpotlight: the index extension acknowledged Spotlight's %@ request", req["request"] as? String ?? "?")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { finish(["acknowledged": true]) }   /* indexing finishes */
    }
    RunLoop.main.run()
    return 0
}
