// isim FileProvider: the protocols an extension implements (items, enumerators, the replicated extension and its
// optional capabilities) and the observers isim passes to it. They are @objc with Apple's Objective-C selectors, so
// Objective-C extensions (sdk-src/Frameworks/FileProvider/FileProvider.h) implement the same ones.
import Foundation
import UniformTypeIdentifiers

// MARK: - items

@objc(NSFileProviderItem)
public protocol NSFileProviderItemProtocol: NSObjectProtocol {
    var itemIdentifier: NSFileProviderItemIdentifier { get }
    var parentItemIdentifier: NSFileProviderItemIdentifier { get }
    var filename: String { get }
    @available(iOS 14.0, *) @objc optional var contentType: UTType { get }
    @available(iOS, introduced: 11.0, deprecated: 15.0, message: "use contentType") @objc optional var typeIdentifier: String { get }
    @objc optional var capabilities: NSFileProviderItemCapabilities { get }
    @available(iOS 16.0, *) @objc optional var extendedAttributes: [String: Data] { get }
    @objc optional var documentSize: NSNumber? { get }
    @objc optional var childItemCount: NSNumber? { get }
    @objc optional var creationDate: Date? { get }
    @objc optional var contentModificationDate: Date? { get }
    @available(iOS 16.0, *) @objc optional var fileSystemFlags: NSFileProviderFileSystemFlags { get }
    @available(iOS 16.0, *) @objc optional var typeAndCreator: NSFileProviderTypeAndCreator { get }
    @objc optional var lastUsedDate: Date? { get }
    @objc optional var tagData: Data? { get }
    @objc optional var favoriteRank: NSNumber? { get }
    @objc optional var isTrashed: Bool { get }
    @objc optional var isUploaded: Bool { get }
    @objc optional var isUploading: Bool { get }
    @objc optional var uploadingError: (any Error)? { get }
    @objc optional var isDownloaded: Bool { get }
    @objc optional var isDownloading: Bool { get }
    @objc optional var downloadingError: (any Error)? { get }
    @objc optional var isMostRecentVersionDownloaded: Bool { get }
    @objc optional var isShared: Bool { get }
    @objc optional var isSharedByCurrentUser: Bool { get }
    @objc optional var ownerNameComponents: PersonNameComponents? { get }
    @objc optional var mostRecentEditorNameComponents: PersonNameComponents? { get }
    @objc optional var versionIdentifier: Data? { get }
    @available(iOS 16.0, *) @objc optional var itemVersion: NSFileProviderItemVersion { get }
    @available(iOS 16.0, *) @objc optional var symlinkTargetPath: String? { get }
    @objc optional var userInfo: [AnyHashable: Any]? { get }
    @available(iOS 16.0, *) @objc optional var contentPolicy: NSFileProviderContentPolicy { get }
    @available(iOS 27.0, *) @objc optional var namespacePolicy: NSFileProviderNamespacePolicy { get }
}
public typealias NSFileProviderItem = NSFileProviderItemProtocol   // a protocol, so items conform to it (`class Item: NSObject, NSFileProviderItem`)

@available(iOS 16.0, *)
@objc(NSFileProviderItemDecorating)
public protocol NSFileProviderItemDecorating: NSFileProviderItemProtocol {
    var decorations: [NSFileProviderItemDecorationIdentifier]? { get }
}

// MARK: - enumeration

@objc(NSFileProviderEnumerationObserver)
public protocol NSFileProviderEnumerationObserver: NSObjectProtocol {
    @objc(didEnumerateItems:) func didEnumerate(_ updatedItems: [any NSFileProviderItemProtocol])
    @objc(finishEnumeratingUpToPage:) func finishEnumerating(upTo nextPage: NSFileProviderPage?)
    @objc(finishEnumeratingWithError:) func finishEnumeratingWithError(_ error: any Error)
    @objc optional var suggestedPageSize: Int { get }
}

@objc(NSFileProviderChangeObserver)
public protocol NSFileProviderChangeObserver: NSObjectProtocol {
    @objc(didUpdateItems:) func didUpdate(_ updatedItems: [any NSFileProviderItemProtocol])
    @objc(didDeleteItemsWithIdentifiers:) func didDeleteItems(withIdentifiers deletedItemIdentifiers: [NSFileProviderItemIdentifier])
    @objc(finishEnumeratingChangesUpToSyncAnchor:moreComing:) func finishEnumeratingChanges(upTo anchor: NSFileProviderSyncAnchor, moreComing: Bool)
    @objc(finishEnumeratingWithError:) func finishEnumeratingWithError(_ error: any Error)
    @objc optional var suggestedBatchSize: Int { get }
}

@objc(NSFileProviderEnumerator)
public protocol NSFileProviderEnumerator: NSObjectProtocol {
    func invalidate()
    @objc(enumerateItemsForObserver:startingAtPage:)
    func enumerateItems(for observer: any NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage)
    @objc(enumerateChangesForObserver:fromSyncAnchor:)
    optional func enumerateChanges(for observer: any NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor)
    @objc(currentSyncAnchorWithCompletionHandler:)
    optional func currentSyncAnchor(completionHandler: @escaping @Sendable (NSFileProviderSyncAnchor?) -> Void)
}

@available(iOS 16.0, *)
@objc(NSFileProviderPendingSetEnumerator)
public protocol NSFileProviderPendingSetEnumerator: NSFileProviderEnumerator {
    var domainVersion: NSFileProviderDomainVersion? { get }
    var refreshInterval: TimeInterval { get }
    var isMaximumSizeReached: Bool { get }
}

@objc(NSFileProviderEnumerating)
public protocol NSFileProviderEnumerating: NSObjectProtocol {
    @available(iOS 16.0, *)
    @objc(enumeratorForContainerItemIdentifier:request:error:)
    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> any NSFileProviderEnumerator
}

// MARK: - the replicated extension

@available(iOS 16.0, *)
@objc(NSFileProviderReplicatedExtension)
public protocol NSFileProviderReplicatedExtension: NSFileProviderEnumerating {
    @objc(initWithDomain:) init(domain: NSFileProviderDomain)
    func invalidate()
    @objc(itemForIdentifier:request:completionHandler:)
    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest,
              completionHandler: @escaping (NSFileProviderItem?, (any Error)?) -> Void) -> Progress
    @objc(fetchContentsForItemWithIdentifier:version:request:completionHandler:)
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest,
                       completionHandler: @escaping (URL?, NSFileProviderItem?, (any Error)?) -> Void) -> Progress
    @objc(createItemBasedOnTemplate:fields:contents:options:request:completionHandler:)
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions,
                    request: NSFileProviderRequest,
                    completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, (any Error)?) -> Void) -> Progress
    @objc(modifyItem:baseVersion:changedFields:contents:options:request:completionHandler:)
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?,
                    options: NSFileProviderModifyItemOptions, request: NSFileProviderRequest,
                    completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, (any Error)?) -> Void) -> Progress
    @objc(deleteItemWithIdentifier:baseVersion:options:request:completionHandler:)
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions,
                    request: NSFileProviderRequest, completionHandler: @escaping ((any Error)?) -> Void) -> Progress
    @objc(importDidFinishWithCompletionHandler:)
    optional func importDidFinish(completionHandler: @escaping @Sendable () -> Void)
    @objc(materializedItemsDidChangeWithCompletionHandler:)
    optional func materializedItemsDidChange(completionHandler: @escaping @Sendable () -> Void)
    @objc(pendingItemsDidChangeWithCompletionHandler:)
    optional func pendingItemsDidChange(completionHandler: @escaping @Sendable () -> Void)
}

@available(iOS 16.0, *)
@objc(NSFileProviderIncrementalContentFetching)
public protocol NSFileProviderIncrementalContentFetching: NSObjectProtocol {
    @objc(fetchContentsForItemWithIdentifier:version:usingExistingContentsAtURL:existingVersion:request:completionHandler:)
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, usingExistingContentsAt existingContents: URL,
                       existingVersion: NSFileProviderItemVersion, request: NSFileProviderRequest,
                       completionHandler: @escaping (URL?, NSFileProviderItem?, (any Error)?) -> Void) -> Progress
}

@objc(NSFileProviderPartialContentFetching)
public protocol NSFileProviderPartialContentFetching: NSObjectProtocol {
    @objc(fetchPartialContentsForItemWithIdentifier:version:request:minimalRange:aligningTo:options:completionHandler:)
    func fetchPartialContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion, request: NSFileProviderRequest,
                              minimalRange requestedRange: NSRange, aligningTo alignment: Int, options: NSFileProviderFetchContentsOptions,
                              completionHandler: @escaping (URL?, NSFileProviderItem?, NSRange, NSFileProviderMaterializationFlags, (any Error)?) -> Void) -> Progress
}

@objc(NSFileProviderCustomAction)
public protocol NSFileProviderCustomAction: NSObjectProtocol {
    @objc(performActionWithIdentifier:onItemsWithIdentifiers:completionHandler:)
    func performAction(identifier actionIdentifier: NSFileProviderExtensionActionIdentifier, onItemsWithIdentifiers itemIdentifiers: [NSFileProviderItemIdentifier],
                       completionHandler: @escaping ((any Error)?) -> Void) -> Progress
}

@available(iOS 16.0, *)
@objc(NSFileProviderThumbnailing)
public protocol NSFileProviderThumbnailing: NSObjectProtocol {
    @objc(fetchThumbnailsForItemIdentifiers:requestedSize:perThumbnailCompletionHandler:completionHandler:)
    func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize,
                         perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, (any Error)?) -> Void,
                         completionHandler: @escaping ((any Error)?) -> Void) -> Progress
}

@objc(NSFileProviderServiceSource)
public protocol NSFileProviderServiceSource {
    var serviceName: NSFileProviderServiceName { get }
    @objc(makeListenerEndpointAndReturnError:) func makeListenerEndpoint() throws -> NSXPCListenerEndpoint
    @available(iOS 16.0, *) @objc optional var isRestricted: Bool { get }
}

@available(iOS 16.0, *)
@objc(NSFileProviderServicing)
public protocol NSFileProviderServicing: NSObjectProtocol {
    @objc(supportedServiceSourcesForItemIdentifier:completionHandler:)
    func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier,
                                 completionHandler: @escaping ([any NSFileProviderServiceSource]?, (any Error)?) -> Void) -> Progress
}

@available(iOS 16.0, *)
@objc(NSFileProviderDomainState)
public protocol NSFileProviderDomainState: NSObjectProtocol {
    var domainVersion: NSFileProviderDomainVersion { get }
    var userInfo: [AnyHashable: Any] { get }
}

@objc(NSFileProviderExternalVolumeHandling)
public protocol NSFileProviderExternalVolumeHandling: NSObjectProtocol {
    @objc(shouldConnectExternalDomainWithCompletionHandler:)
    func shouldConnectExternalDomain(completionHandler: @escaping @Sendable ((any Error)?) -> Void)
}

@objc(NSFileProviderKnownFolderSupporting)
public protocol NSFileProviderKnownFolderSupporting: NSObjectProtocol {
    @objc(getKnownFolderLocations:completionHandler:)
    func getKnownFolderLocations(_ knownFolders: NSFileProviderKnownFolders,
                                 completionHandler: @escaping @Sendable (NSFileProviderKnownFolderLocations?, (any Error)?) -> Void)
}

@objc(NSFileProviderUserInteractionSuppressing)
public protocol NSFileProviderUserInteractionSuppressing: NSObjectProtocol {
    @objc(setInteractionSuppressed:forIdentifier:) func setInteractionSuppressed(_ suppression: Bool, forIdentifier suppressionIdentifier: String)
    @objc(isInteractionSuppressedForIdentifier:) func isInteractionSuppressed(forIdentifier suppressionIdentifier: String) -> Bool
}

// MARK: - search

@objc(NSFileProviderSearchResult)
public protocol NSFileProviderSearchResult {
    var itemIdentifier: NSFileProviderItemIdentifier { get }
    var filename: String { get }
    var contentType: UTType { get }
    var documentSize: NSNumber? { get }
    var creationDate: Date? { get }
    var contentModificationDate: Date? { get }
    var lastUsedDate: Date? { get }
}

@objc(NSFileProviderSearchEnumerationObserver)
public protocol NSFileProviderSearchEnumerationObserver: NSObjectProtocol {
    @objc(didEnumerateSearchResults:) func didEnumerate(_ searchResults: [any NSFileProviderSearchResult])
    @objc(finishEnumeratingUpToPage:) func finishEnumerating(upTo nextPage: NSFileProviderPage?)
    @objc(finishEnumeratingWithError:) func finishEnumeratingWithError(_ error: any Error)
    var maximumNumberOfResultsPerPage: Int { get }
}

@objc(NSFileProviderSearchEnumerator)
public protocol NSFileProviderSearchEnumerator: NSObjectProtocol {
    @objc(enumerateSearchResultsForObserver:startingAtPage:)
    func enumerateSearchResults(for observer: any NSFileProviderSearchEnumerationObserver, startingAt page: NSFileProviderPage?)
    func invalidate()
}

@objc(NSFileProviderSearching)
public protocol NSFileProviderSearching: NSObjectProtocol {
    @objc(searchEnumeratorForRequest:) func searchEnumerator(for request: NSFileProviderStringSearchRequest) -> any NSFileProviderSearchEnumerator
}

// MARK: - testing operations (stub: isim lists none)

@available(iOS 16.0, *)
@objc(NSFileProviderTestingOperation)
public protocol NSFileProviderTestingOperation: NSObjectProtocol {
    var type: NSFileProviderTestingOperationType { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingIngestion)
public protocol NSFileProviderTestingIngestion: NSFileProviderTestingOperation {
    var side: NSFileProviderTestingOperationSide { get }
    var itemIdentifier: NSFileProviderItemIdentifier { get }
    var item: NSFileProviderItem? { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingLookup)
public protocol NSFileProviderTestingLookup: NSFileProviderTestingOperation {
    var side: NSFileProviderTestingOperationSide { get }
    var itemIdentifier: NSFileProviderItemIdentifier { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingCreation)
public protocol NSFileProviderTestingCreation: NSFileProviderTestingOperation {
    var targetSide: NSFileProviderTestingOperationSide { get }
    var sourceItem: NSFileProviderItem { get }
    var domainVersion: NSFileProviderDomainVersion? { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingModification)
public protocol NSFileProviderTestingModification: NSFileProviderTestingOperation {
    var targetSide: NSFileProviderTestingOperationSide { get }
    var sourceItem: NSFileProviderItem { get }
    var targetItemIdentifier: NSFileProviderItemIdentifier { get }
    var targetItemBaseVersion: NSFileProviderItemVersion { get }
    var changedFields: NSFileProviderItemFields { get }
    var domainVersion: NSFileProviderDomainVersion? { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingDeletion)
public protocol NSFileProviderTestingDeletion: NSFileProviderTestingOperation {
    var targetSide: NSFileProviderTestingOperationSide { get }
    var sourceItemIdentifier: NSFileProviderItemIdentifier { get }
    var targetItemIdentifier: NSFileProviderItemIdentifier { get }
    var targetItemBaseVersion: NSFileProviderItemVersion { get }
    var domainVersion: NSFileProviderDomainVersion? { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingContentFetch)
public protocol NSFileProviderTestingContentFetch: NSFileProviderTestingOperation {
    var side: NSFileProviderTestingOperationSide { get }
    var itemIdentifier: NSFileProviderItemIdentifier { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingChildrenEnumeration)
public protocol NSFileProviderTestingChildrenEnumeration: NSFileProviderTestingOperation {
    var side: NSFileProviderTestingOperationSide { get }
    var itemIdentifier: NSFileProviderItemIdentifier { get }
}
@available(iOS 16.0, *) @objc(NSFileProviderTestingCollisionResolution)
public protocol NSFileProviderTestingCollisionResolution: NSFileProviderTestingOperation {
    var side: NSFileProviderTestingOperationSide { get }
    var renamedItem: NSFileProviderItem { get }
}
