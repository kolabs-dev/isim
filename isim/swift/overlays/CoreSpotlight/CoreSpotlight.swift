// isim CoreSpotlight: CSSearchableIndex stores items in the device-wide Spotlight index the home screen searches
// (<isim data>/Library/Spotlight/<bundle id>.plist, shared with NSUserActivity indexing). Choosing a result in the
// home screen's Spotlight continues an NSUserActivity of type CSSearchableItemActionType in the app, with
// userInfo[CSSearchableItemActivityIdentifier] = the item's uniqueIdentifier, like iOS.
// Not implemented: CSSearchQuery (in-app queries; 🧩 returns no results), index delegates, protection classes.
import Foundation
import UniformTypeIdentifiers

public let CSSearchableItemActionType = "com.apple.corespotlightitem"
public let CSSearchableItemActivityIdentifier = "kCSSearchableItemActivityIdentifier"
public let CSQueryContinuationActionType = "com.apple.corespotlightquerycontinuation"
public let CSSearchQueryString = "kCSSearchQueryString"

open class CSSearchableItemAttributeSet: NSObject {
    public let contentType: String
    open var title: String?
    open var displayName: String?
    open var contentDescription: String?
    open var keywords: [String]?
    open var thumbnailData: Data?
    open var thumbnailURL: URL?
    open var contentURL: URL?
    open var url: URL?
    open var identifier: String?
    open var relatedUniqueIdentifier: String?
    open var phoneNumbers: [String]?
    open var emailAddresses: [String]?
    open var startDate: Date?
    open var endDate: Date?
    open var rating: NSNumber?
    public init(contentType: UTType) { self.contentType = contentType.identifier }
    public init(itemContentType: String) { self.contentType = itemContentType }
}

open class CSSearchableItem: NSObject {
    open var uniqueIdentifier: String
    open var domainIdentifier: String?
    open var attributeSet: CSSearchableItemAttributeSet
    open var expirationDate: Date!
    public init(uniqueIdentifier: String?, domainIdentifier: String?, attributeSet: CSSearchableItemAttributeSet) {
        self.uniqueIdentifier = uniqueIdentifier ?? UUID().uuidString
        self.domainIdentifier = domainIdentifier
        self.attributeSet = attributeSet
        self.expirationDate = Date(timeIntervalSinceNow: 30 * 24 * 3600)
    }
}

public struct CSIndexError: Swift.Error, Sendable {
    public enum Code: Int, Sendable { case unknownError = -1, indexUnavailableError = -1000, invalidItemError = -1001, invalidClientStateError = -1002,
                                      remoteConnectionError = -1003, quotaExceeded = -1004, indexingUnsupported = -1005 }
    public let code: Code
}

open class CSSearchableIndex: NSObject, @unchecked Sendable {
    private static let shared = CSSearchableIndex(name: "default")
    open class func `default`() -> CSSearchableIndex { shared }
    open class func isIndexingAvailable() -> Bool { true }
    public let name: String
    public init(name: String) { self.name = name }

    static let lock = NSLock()
    static var file: String {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim"))
        let dir = (data as NSString).appendingPathComponent("Library/Spotlight")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        return (dir as NSString).appendingPathComponent((Bundle.main.bundleIdentifier ?? "unknown") + ".plist")
    }
    static func update(_ edit: (inout [[String: Any]]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var items = (NSDictionary(contentsOfFile: file) as? [String: Any])?["items"] as? [[String: Any]] ?? []
        edit(&items)
        (["items": items] as NSDictionary).write(toFile: file, atomically: true)
    }
    static func done(_ h: ((Swift.Error?) -> Void)?) { if let h { DispatchQueue.global().async { h(nil) } } }

    open func indexSearchableItems(_ items: [CSSearchableItem], completionHandler: ((Swift.Error?) -> Void)? = nil) {
        CSSearchableIndex.update { list in
            for it in items {
                list.removeAll { ($0["id"] as? String) == it.uniqueIdentifier }
                var e: [String: Any] = ["id": it.uniqueIdentifier, "kind": "item", "domain": it.domainIdentifier ?? "",
                                        "title": it.attributeSet.title ?? it.attributeSet.displayName ?? "",
                                        "contentType": it.attributeSet.contentType]
                if let d = it.attributeSet.contentDescription { e["description"] = d }
                if let k = it.attributeSet.keywords { e["keywords"] = k }
                list.append(e)
            }
        }
        NSLog("isim CoreSpotlight: indexed %ld item(s) for Spotlight", items.count)
        CSSearchableIndex.done(completionHandler)
    }
    open func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in indexSearchableItems(items) { _ in k.resume() } }
    }
    open func deleteSearchableItems(withIdentifiers identifiers: [String], completionHandler: ((Swift.Error?) -> Void)? = nil) {
        CSSearchableIndex.update { list in list.removeAll { ($0["kind"] as? String) == "item" && identifiers.contains(($0["id"] as? String) ?? "") } }
        CSSearchableIndex.done(completionHandler)
    }
    open func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in deleteSearchableItems(withIdentifiers: identifiers) { _ in k.resume() } }
    }
    open func deleteSearchableItems(withDomainIdentifiers domains: [String], completionHandler: ((Swift.Error?) -> Void)? = nil) {
        CSSearchableIndex.update { list in
            list.removeAll { e in
                guard (e["kind"] as? String) == "item", let d = e["domain"] as? String else { return false }
                return domains.contains { d == $0 || d.hasPrefix($0 + ".") }
            }
        }
        CSSearchableIndex.done(completionHandler)
    }
    open func deleteSearchableItems(withDomainIdentifiers domains: [String]) async throws {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in deleteSearchableItems(withDomainIdentifiers: domains) { _ in k.resume() } }
    }
    open func deleteAllSearchableItems(completionHandler: ((Swift.Error?) -> Void)? = nil) {
        CSSearchableIndex.update { list in list.removeAll { ($0["kind"] as? String) == "item" } }
        CSSearchableIndex.done(completionHandler)
    }
    open func deleteAllSearchableItems() async throws {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in deleteAllSearchableItems { _ in k.resume() } }
    }
}

/// In-app queries over the app's own index. isim: not implemented (no results; the completion runs).
open class CSSearchQuery: NSObject {
    open var foundItemsHandler: (([CSSearchableItem]) -> Void)?
    open var completionHandler: ((Swift.Error?) -> Void)?
    public let queryString: String
    public init(queryString: String, attributes: [String]?) { self.queryString = queryString }
    open func start() { NSLog("isim CoreSpotlight: CSSearchQuery is not implemented (no results)"); let c = completionHandler; DispatchQueue.global().async { c?(nil) } }
    open func cancel() {}
}
