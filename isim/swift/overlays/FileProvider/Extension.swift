// isim FileProvider: NSFileProviderExtension, the non-replicated extension of iOS 11 (stub). Apps can subclass it and
// build, but isim hosts only replicated extensions: none of these methods is called by isim, and the base class's
// answer, like Apple's, is that the operation is not supported.
import Foundation
import UniformTypeIdentifiers

@objc(NSFileProviderExtension)
open class NSFileProviderExtension: NSObject {
    public override init() {}
    static var unsupported: NSError {
        NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [NSLocalizedDescriptionKey: "implement this method in your NSFileProviderExtension subclass"])
    }

    @objc open var domain: NSFileProviderDomain? { nil }
    @objc open var documentStorageURL: URL { NSFileProviderManager.default.documentStorageURL }
    @objc open var providerIdentifier: String { NSFileProviderManager.default.providerIdentifier }

    @objc(itemForIdentifier:error:) open func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(URLForItemWithPersistentIdentifier:) open func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? { nil }
    @objc(persistentIdentifierForItemAtURL:) open func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? { nil }
    @objc(providePlaceholderAtURL:completionHandler:)
    open func providePlaceholder(at url: URL, completionHandler: @escaping @Sendable ((any Error)?) -> Void) { completionHandler(Self.unsupported) }
    open func providePlaceholder(at url: URL) async throws { throw Self.unsupported }
    @objc(startProvidingItemAtURL:completionHandler:)
    open func startProvidingItem(at url: URL, completionHandler: @escaping @Sendable ((any Error)?) -> Void) { completionHandler(Self.unsupported) }
    open func startProvidingItem(at url: URL) async throws { throw Self.unsupported }
    @objc(stopProvidingItemAtURL:) open func stopProvidingItem(at url: URL) {}
    @objc(itemChangedAtURL:) open func itemChanged(at url: URL) {}
    @objc(enumeratorForContainerItemIdentifier:error:)
    open func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> any NSFileProviderEnumerator { throw Self.unsupported }

    @objc(importDocumentAtURL:toParentItemIdentifier:completionHandler:)
    open func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
                             completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(createDirectoryWithName:inParentItemIdentifier:completionHandler:)
    open func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
                              completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(renameItemWithIdentifier:toName:completionHandler:)
    open func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String,
                         completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(reparentItemWithIdentifier:toParentItemWithIdentifier:newName:completionHandler:)
    open func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
                           newName: String?, completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
                           newName: String?) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(trashItemWithIdentifier:completionHandler:)
    open func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
                        completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(untrashItemWithIdentifier:toParentItemIdentifier:completionHandler:)
    open func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?,
                          completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(deleteItemWithIdentifier:completionHandler:)
    open func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable ((any Error)?) -> Void) { completionHandler(Self.unsupported) }
    open func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws { throw Self.unsupported }
    @objc(setLastUsedDate:forItemIdentifier:completionHandler:)
    open func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier,
                              completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(setTagData:forItemIdentifier:completionHandler:)
    open func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier,
                         completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(setFavoriteRank:forItemIdentifier:completionHandler:)
    open func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier,
                              completionHandler: @escaping @Sendable (NSFileProviderItem?, (any Error)?) -> Void) { completionHandler(nil, Self.unsupported) }
    open func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem { throw Self.unsupported }
    @objc(fetchThumbnailsForItemIdentifiers:requestedSize:perThumbnailCompletionHandler:completionHandler:)
    open func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize,
                              perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, (any Error)?) -> Void,
                              completionHandler: @escaping ((any Error)?) -> Void) -> Progress {
        completionHandler(Self.unsupported)
        return Progress(totalUnitCount: 0)
    }
    @objc(supportedServiceSourcesForItemIdentifier:error:)
    open func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier) throws -> [any NSFileProviderServiceSource] { [] }

    @objc(writePlaceholderAtURL:withMetadata:error:)
    open class func writePlaceholder(at placeholderURL: URL, withMetadata metadata: [URLResourceKey: Any]) throws {
        FileManager.default.createFile(atPath: placeholderURL.path, contents: Data())
    }
    @objc(placeholderURLForURL:)
    open class func placeholderURL(for url: URL) -> URL { NSFileProviderManager.placeholderURL(for: url) }
}
