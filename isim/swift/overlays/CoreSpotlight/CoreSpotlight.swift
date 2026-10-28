// isim CoreSpotlight: CSSearchableIndex stores items in the device-wide Spotlight index the home screen searches
// (<isim data>/Library/Spotlight/<bundle id>.plist, shared with NSUserActivity indexing). Choosing a result in the
// home screen's Spotlight continues an NSUserActivity of type CSSearchableItemActionType in the app, with
// userInfo[CSSearchableItemActivityIdentifier] = the item's uniqueIdentifier, like iOS.
// Each item keeps all its attributes (Attributes.swift), which CSSearchQuery and CSUserQuery search (Query.swift); the
// index delegate and Spotlight's index and import extensions are in Delegate.swift. Protection classes are kept, not
// enforced (isim's files have no data protection).
import Foundation
import UniformTypeIdentifiers

public let CSSearchableItemActionType = "com.apple.corespotlightitem"
public let CSSearchableItemActivityIdentifier = "kCSSearchableItemActivityIdentifier"
public let CSQueryContinuationActionType = "com.apple.corespotlightquerycontinuation"
public let CSSearchQueryString = "kCSSearchQueryString"
public let CSActionIdentifier = "kCSActionIdentifier"
public let CSIndexErrorDomain = "CSIndexErrorDomain"
public let CSSearchQueryErrorDomain = "CSSearchQueryErrorDomain"
public let CSMailboxInbox = "com.apple.mail.inbox"
public let CSMailboxDrafts = "com.apple.mail.drafts"
public let CSMailboxSent = "com.apple.mail.sent"
public let CSMailboxJunk = "com.apple.mail.junk"
public let CSMailboxTrash = "com.apple.mail.trash"
public let CSMailboxArchive = "com.apple.mail.archive"
public var CoreSpotlightAPIVersion: Int32 { 1 }

@objc(CSSearchableItem) open class CSSearchableItem: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    open var uniqueIdentifier: String
    open var domainIdentifier: String?
    open var attributeSet: CSSearchableItemAttributeSet
    open var expirationDate: Date!
    /// iOS 16: the item updates the indexed one (its attributes are merged into it) instead of replacing it
    @objc(isUpdate) open var isUpdate: Bool = false
    /// iOS 18: what Spotlight tells the index delegate about the item (searchableItemsDidUpdate)
    @available(iOS 18.0, *)
    open var updateListenerOptions: UpdateListenerOptions {
        get { UpdateListenerOptions(rawValue: _updateListenerOptions) }
        set { _updateListenerOptions = newValue.rawValue }
    }
    var _updateListenerOptions: UInt = 0
    /// the app entity the item stands for (AppIntents' IndexedEntity, associateAppEntity): type and identifier
    public var _isimAppEntity: [String: String]?
    /// a found item's rank (CSUserQuery's ranked results; higher first)
    var _rank: Double = 0
    public init(uniqueIdentifier: String?, domainIdentifier: String?, attributeSet: CSSearchableItemAttributeSet) {
        self.uniqueIdentifier = uniqueIdentifier ?? UUID().uuidString
        self.domainIdentifier = domainIdentifier
        self.attributeSet = attributeSet
        self.expirationDate = Date(timeIntervalSinceNow: 30 * 24 * 3600)
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(forKey: "uniqueIdentifier") as? String,
              let a = coder.decodeObject(forKey: "attributeSet") as? [String: Any] else { return nil }
        uniqueIdentifier = id; domainIdentifier = coder.decodeObject(forKey: "domainIdentifier") as? String
        attributeSet = CSSearchableItemAttributeSet(_isimPlist: a)
        expirationDate = coder.decodeObject(forKey: "expirationDate") as? Date ?? Date(timeIntervalSinceNow: 30 * 24 * 3600)
        isUpdate = coder.decodeBool(forKey: "isUpdate")
    }
    open func encode(with coder: NSCoder) {
        coder.encode(uniqueIdentifier, forKey: "uniqueIdentifier"); coder.encode(domainIdentifier, forKey: "domainIdentifier")
        coder.encode(attributeSet._isimPlist as NSDictionary, forKey: "attributeSet"); coder.encode(expirationDate, forKey: "expirationDate")
        coder.encode(isUpdate, forKey: "isUpdate")
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        let c = CSSearchableItem(uniqueIdentifier: uniqueIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributeSet.copy() as! CSSearchableItemAttributeSet)
        c.expirationDate = expirationDate; c.isUpdate = isUpdate; c._updateListenerOptions = _updateListenerOptions
        c._isimAppEntity = _isimAppEntity; c._rank = _rank
        return c
    }
    /// iOS 18: by rank (a ranked CSUserQuery's results; higher ranks first)
    @objc(compareByRank:) open func compare(byRank other: CSSearchableItem) -> ComparisonResult {
        _rank == other._rank ? .orderedSame : _rank > other._rank ? .orderedAscending : .orderedDescending
    }
    /// what the index keeps for the item
    var _entry: [String: Any] {
        var e: [String: Any] = ["id": uniqueIdentifier, "kind": "item", "domain": domainIdentifier ?? "",
                                "title": attributeSet.title ?? attributeSet.displayName ?? "", "contentType": attributeSet.contentType ?? "",
                                "attributes": attributeSet._isimPlist]
        if let d = attributeSet.contentDescription { e["description"] = d }
        if let k = attributeSet.keywords { e["keywords"] = k }
        if let x = expirationDate { e["expires"] = x }
        if let entity = _isimAppEntity { e["appEntity"] = entity["type"]; e["entityID"] = entity["id"] }
        return e
    }
    /// an item from the index (fetch: the attributes a query asked for, or all)
    convenience init(_entry e: [String: Any], fetch: [String]? = nil) {
        var attrs = e["attributes"] as? [String: Any] ?? [:]
        if attrs.isEmpty {                                  /* indexed before isim kept every attribute */
            attrs["title"] = e["title"]; attrs["contentDescription"] = e["description"]; attrs["keywords"] = e["keywords"]
            attrs["contentType"] = e["contentType"]
        }
        if let fetch, !fetch.isEmpty { attrs = attrs.filter { fetch.contains($0.key) || $0.key == "contentType" } }
        let d = e["domain"] as? String
        self.init(uniqueIdentifier: e["id"] as? String ?? "", domainIdentifier: (d?.isEmpty ?? true) ? nil : d, attributeSet: CSSearchableItemAttributeSet(_isimPlist: attrs))
        if let x = e["expires"] as? Date { expirationDate = x }
    }

    @available(iOS 18.0, *)
    public struct UpdateListenerOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var summarization: UpdateListenerOptions { UpdateListenerOptions(rawValue: 1 << 1) }
        public static var priority: UpdateListenerOptions { UpdateListenerOptions(rawValue: 1 << 2) }
    }
}

public struct CSIndexError: Swift.Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable { case unknownError = -1, indexUnavailableError = -1000, invalidItemError = -1001, invalidClientStateError = -1002,
                                      remoteConnectionError = -1003, quotaExceeded = -1004, indexingUnsupported = -1005, mismatchedClientState = -1006 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CSIndexErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var unknownError: Code { .unknownError }
    public static var indexUnavailableError: Code { .indexUnavailableError }
    public static var invalidItemError: Code { .invalidItemError }
    public static var invalidClientStateError: Code { .invalidClientStateError }
    public static var remoteConnectionError: Code { .remoteConnectionError }
    public static var quotaExceeded: Code { .quotaExceeded }
    public static var indexingUnsupported: Code { .indexingUnsupported }
    public static var mismatchedClientState: Code { .mismatchedClientState }
}

@objc(CSSearchableIndex) open class CSSearchableIndex: NSObject, @unchecked Sendable {
    private static let shared = CSSearchableIndex(name: "default")
    open class func `default`() -> Self {
        guard let s = shared as? Self else { fatalError("CSSearchableIndex.default() is the app's default index, not a \(self)") }
        return s
    }
    open class func isIndexingAvailable() -> Bool { true }
    public let name: String
    /// kept for the record: isim's files have no data protection
    open private(set) var protectionClass: FileProtectionType = .completeUntilFirstUserAuthentication
    /// the app's object that reindexes items and provides their data when Spotlight asks (Delegate.swift)
    open weak var indexDelegate: (any CSSearchableIndexDelegate)? {
        didSet { if indexDelegate != nil { _CSDelegateListener.listen(self) } }
    }
    public init(name: String) { self.name = name }
    public init(name: String, protectionClass: FileProtectionType?) {
        self.name = name
        if let protectionClass { self.protectionClass = protectionClass }
    }

    static let lock = NSLock()
    static var dataDir: String {
        ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim"))
    }
    /// the app's index (an extension's: its app's)
    static var bundleID: String {
        let b = Bundle.main.bundleIdentifier ?? "unknown"
        if Bundle.main.bundlePath.hasSuffix(".appex"), let app = Bundle(path: ((Bundle.main.bundlePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent)?.bundleIdentifier {
            return app
        }
        return b
    }
    static var file: String {
        let dir = (dataDir as NSString).appendingPathComponent("Library/Spotlight")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        return (dir as NSString).appendingPathComponent(bundleID + ".plist")
    }
    static func read() -> [String: Any] { lock.lock(); defer { lock.unlock() }; return (NSDictionary(contentsOfFile: file) as? [String: Any]) ?? [:] }
    static func update(_ edit: (inout [[String: Any]], inout [String: Any]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var all = (NSDictionary(contentsOfFile: file) as? [String: Any]) ?? [:]
        var items = all["items"] as? [[String: Any]] ?? []
        edit(&items, &all)
        all["items"] = items
        (all as NSDictionary).write(toFile: file, atomically: true)
    }
    static func update(_ edit: (inout [[String: Any]]) -> Void) { update { items, _ in edit(&items) } }
    static func done(_ h: ((Swift.Error?) -> Void)?, _ error: Swift.Error? = nil) { if let h { DispatchQueue.global().async { h(error) } } }
    /// the index's own items (items written before named indexes are the default index's)
    func mine(_ e: [String: Any]) -> Bool { (e["kind"] as? String) == "item" && ((e["index"] as? String) ?? "default") == name }

    // MARK: batches (beginBatch / endBatch: the operations apply together, with the app's client state)
    private var batch: [(inout [[String: Any]]) -> Void]?
    open func beginBatch() { batch = [] }
    private func apply(_ op: @escaping (inout [[String: Any]]) -> Void, _ h: ((Swift.Error?) -> Void)?) {
        if batch != nil { batch!.append(op); CSSearchableIndex.done(h); return }
        CSSearchableIndex.update(op)
        CSSearchableIndex.done(h)
    }
    open func endBatch(withClientState clientState: Data, completionHandler: ((Swift.Error?) -> Void)? = nil) {
        endIndexBatch(expectedClientState: nil, newClientState: clientState, completionHandler: completionHandler)
    }
    /// iOS 17: the batch applies only if the stored client state is the expected one (mismatchedClientState otherwise)
    open func endIndexBatch(expectedClientState: Data?, newClientState: Data, completionHandler: ((Swift.Error?) -> Void)? = nil) {
        let ops = batch ?? []
        batch = nil
        var mismatch = false
        CSSearchableIndex.update { items, all in
            var states = all["clientStates"] as? [String: Data] ?? [:]
            if let expectedClientState, states[name] != expectedClientState { mismatch = true; return }
            for op in ops { op(&items) }
            states[name] = newClientState
            all["clientStates"] = states
        }
        NSLog("isim CoreSpotlight: %@ batch of %ld operation(s)%@", name, ops.count, mismatch ? " not applied: the client state does not match" : "")
        CSSearchableIndex.done(completionHandler, mismatch ? CSIndexError(.mismatchedClientState) : nil)
    }
    open func fetchLastClientState(completionHandler: @escaping (Data?, Swift.Error?) -> Void) {
        let state = (CSSearchableIndex.read()["clientStates"] as? [String: Data])?[name]
        DispatchQueue.global().async { completionHandler(state, nil) }
    }

    // MARK: indexing
    open func indexSearchableItems(_ items: [CSSearchableItem], completionHandler: ((Swift.Error?) -> Void)? = nil) {
        let name = self.name
        let entries = items.map { it -> [String: Any] in var e = it._entry; e["index"] = name; e["update"] = it.isUpdate; return e }
        apply({ list in
            for var e in entries {
                let id = e["id"] as? String
                if let old = list.firstIndex(where: { ($0["id"] as? String) == id && (($0["index"] as? String) ?? "default") == name && ($0["kind"] as? String) == "item" }) {
                    if (e["update"] as? Bool) == true {             /* isUpdate: merge the new attributes into the indexed ones */
                        var attrs = list[old]["attributes"] as? [String: Any] ?? [:]
                        for (k, v) in e["attributes"] as? [String: Any] ?? [:] { attrs[k] = v }
                        e["attributes"] = attrs
                        e["title"] = (attrs["title"] as? String) ?? (attrs["displayName"] as? String) ?? list[old]["title"]
                        e["engaged"] = list[old]["engaged"]
                    }
                    list.remove(at: old)
                }
                e.removeValue(forKey: "update")
                list.append(e)
            }
        }, completionHandler)
        NSLog("isim CoreSpotlight: indexed %ld item(s) for Spotlight", items.count)
        _CSDelegateListener.itemsIndexed(items, by: self)
    }
    open func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Swift.Error>) in
            indexSearchableItems(items) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func deleteSearchableItems(withIdentifiers identifiers: [String], completionHandler: ((Swift.Error?) -> Void)? = nil) {
        apply({ [weak self] list in list.removeAll { (self?.mine($0) ?? false) && identifiers.contains(($0["id"] as? String) ?? "") } }, completionHandler)
    }
    open func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Swift.Error>) in
            deleteSearchableItems(withIdentifiers: identifiers) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func deleteSearchableItems(withDomainIdentifiers domains: [String], completionHandler: ((Swift.Error?) -> Void)? = nil) {
        apply({ [weak self] list in
            list.removeAll { e in
                guard self?.mine(e) ?? false, let d = e["domain"] as? String else { return false }
                return domains.contains { d == $0 || d.hasPrefix($0 + ".") }
            }
        }, completionHandler)
    }
    open func deleteSearchableItems(withDomainIdentifiers domains: [String]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Swift.Error>) in
            deleteSearchableItems(withDomainIdentifiers: domains) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func deleteAllSearchableItems(completionHandler: ((Swift.Error?) -> Void)? = nil) {
        apply({ [weak self] list in list.removeAll { self?.mine($0) ?? false } }, completionHandler)
    }
    open func deleteAllSearchableItems() async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Swift.Error>) in
            deleteAllSearchableItems { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }

    /// iOS 17: an item's data of a type, from the app's index delegate (the app's own items only, as on iOS)
    open func fetchData(forBundleIdentifier bundleIdentifier: String, itemIdentifier: String, contentType: UTType, completionHandler: @escaping (Data?, Swift.Error?) -> Void) {
        guard bundleIdentifier == CSSearchableIndex.bundleID, let d = indexDelegate, d.responds(to: #selector(CSSearchableIndexDelegate.data(for:itemIdentifier:typeIdentifier:))) else {
            DispatchQueue.global().async { completionHandler(nil, CSIndexError(.invalidItemError)) }
            return
        }
        do {
            let data = try d.data!(for: self, itemIdentifier: itemIdentifier, typeIdentifier: contentType.identifier)
            DispatchQueue.global().async { completionHandler(data, nil) }
        } catch {
            DispatchQueue.global().async { completionHandler(nil, error) }
        }
    }
}
