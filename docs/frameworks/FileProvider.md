# FileProvider

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (504 of 504, exact) · **Rows:** 12: 7 ✅ 5 🟡 · **iOS:** 11.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [FileProvider](https://developer.apple.com/documentation/fileprovider) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/FileProvider`; the system side is `Host.swift`, the picker side
  `isim/frameworks/UIKit/UIDocumentPicker.m`):
  - `NSFileProviderManager.add(_:)` registers a domain of the app's replicated file provider extension
    (`com.apple.fileprovider-nonui`) on the device (`<isim data>/Library/isim/FileProvider/domains.json`);
  - each domain is a location in the document picker and browser, after On My iPhone, with the provider app's icon.
    Its replica (`…/FileProvider/Domains/<extension>/<domain>/`) is the domain's user-visible URL;
  - isim's system side, iOS's `fileproviderd`, loads the extension into the process that uses the domain (the
    picker's app, or the provider app for its manager calls). iOS runs it in a process of its own; the extension keeps
    its app groups. It then syncs:
    - the replica holds folders and placeholders (a file of the item's size with no data, shown with a cloud badge)
      until a file is picked or downloaded (`fetchContents`), unless the item's `contentPolicy` downloads it eagerly;
    - a sync sends local changes first: a new file or folder is `createItem`, a changed file `modifyItem`, a removed
      one `deleteItem` (a move is a deletion and a creation);
    - it then takes the extension's changes: `enumerateChanges` on the working set from the last sync anchor, or a full
      enumeration from the root container (the first time, an expired anchor, no `enumerateChanges`);
  - the picker syncs a domain when it opens it, downloads the files it returns and commits the files exported or
    moved into it. `signalEnumerator`, `waitForStabilization` and `getUserVisibleURL` sync too;
  - an item's menu (a long press) has the actions of the extension's `NSExtensionFileProviderActions` whose
    activation rule holds (an `NSPredicate` over `fileproviderItems`): `NSFileProviderCustomAction` actions, and the
    FileProviderUI extension's ([FileProviderUI](FileProviderUI.md));
  - `isim fileprovider list` prints the domains and their replicas; `isim fileprovider files DOMAIN` prints a domain's
    items, with "(placeholder)" for those not downloaded.
- **Objective-C / C interface:** `sdk-src/Frameworks/FileProvider/FileProvider.h` declares the value types (option
  sets, enums, identifiers, `NSFileProviderTypeAndCreator`, the error domain and keys) for both languages, like Apple's
  header; the classes and protocols are the overlay's (FileProvider.framework re-exports it), declared for
  Objective-C only. Objective-C items and extensions implement the same protocols.
- **Versus Apple's Simulator:** there is no Files app on isim yet: the document picker and browser are where domains
  show. Moves and renames in the replica reach the extension as a deletion and a creation, not a `modifyItem` of the
  parent or name. There are no thumbnails, decorations or sharing UI in the picker. Testing modes list no operations,
  and services are not reachable from other apps.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NSFileProviderReplicatedExtension` (`init(domain:)`, `invalidate`, `item(for:)`, `fetchContents`, `createItem`, `modifyItem`, `deleteItem`, `enumerator(for:request:)`, `importDidFinish`, `materializedItemsDidChange`, `pendingItemsDidChange`), `NSFileProviderEnumerating` | ✅ | 16.0 | adapted: loaded in-process by isim's system side (a Swift or Objective-C principal class); replica sync as above. Tested: test_file_provider (HelloFileProvider) |
| `NSFileProviderEnumerator` (`enumerateItems`, `enumerateChanges`, `currentSyncAnchor`, `invalidate`), `NSFileProviderEnumerationObserver`, `NSFileProviderChangeObserver`, `NSFileProviderPage` (initial pages), `NSFileProviderSyncAnchor` | ✅ | ≤17 | pages are followed until `finishEnumerating(upTo: nil)`; an expired anchor (`syncAnchorExpired`) enumerates everything again. Tested: test_file_provider |
| `NSFileProviderItem` / `NSFileProviderItemProtocol` (identifier, parent, filename, `contentType`, `documentSize`, `itemVersion`, `contentPolicy`, `isTrashed`, dates, the other optional properties), `NSFileProviderItemVersion`, `NSFileProviderItemCapabilities`, `NSFileProviderItemFields`, `NSFileProviderItemIdentifier` (`rootContainer`, `workingSet`, `trashContainer`) | ✅ | ≤17 | folders are items whose content type conforms to `public.directory`; trashed items are left out of the replica. Tested: test_file_provider, test_services_objc (an Objective-C item) |
| `NSFileProviderManager`: domains (`add`, `remove` (and `mode:`), `removeAllDomains`, `getDomains` / `domains()`, `init(for:)`, `import(_:fromDirectoryAt:)`), `signalEnumerator`, `getUserVisibleURL`, `getIdentifierForUserVisibleFile`, `requestDownloadForItem`, `evictItem`, `waitForChanges(below:)`, `waitForStabilization`, `reimportItems(below:)`, `requestModification`, `signalErrorResolved`, `reconnect` / `disconnect`, `temporaryDirectoryURL`, `stateDirectoryURL`, `enumeratorForMaterializedItems`, `enumeratorForPendingItems`, `providerIdentifier`, `documentStorageURL`, `placeholderURL(for:)`, `writePlaceholder` | ✅ | ≤17 | adapted: the device's domains and replicas; a disconnected domain does not show in the picker; a removal with a preserving mode keeps the replica's files in a folder and returns it; there are no pending items (local changes are sent at once). Tested: test_file_provider (add, list, signal, visible URL, download, evict, remove), test_services_objc |
| `NSFileProviderCustomAction`, `NSExtensionFileProviderActions` (`…ActionIdentifier`, `…ActionName`, `…ActionActivationRule`) | ✅ | ≤17 | adapted: in the picker's item menu; the activation rule is evaluated with `fileproviderItems` (identifier, filename, `contentType.identifier`, `isFolder`, `isDownloaded`, `documentSize`). Tested: test_file_provider (Star) |
| `NSFileProviderDomain` (identifiers, display name, `isHidden`, `isDisconnected`, `userEnabled`, `isReplicated`, `testingModes`, `supportsSyncingTrash`, `userInfo`), `NSFileProviderDomainIdentifier`, `NSFileProviderDomainVersion`, `NSFileProviderRequest` (`isSystemRequest`, `isFileViewerRequest`, `requestingExecutable`, `domainVersion`) | ✅ | ≤17 | the picker's fetches are file viewer requests; syncs are system requests. Tested: test_file_provider (viewer=true / false), test_services_objc |
| `NSFileProviderError` (all codes), `NSFileProviderErrorDomain`, `NSFileProviderErrorCollidingItemKey`, `…ItemKey`, `…NonExistentItemIdentifierKey` | ✅ | ≤17 | Apple's codes; adding a domain without an extension is `providerNotFound`. Tested: test_services_objc |
| `NSFileProviderContentPolicy`, `NSFileProviderNamespacePolicy` (iOS 27), `NSFileProviderFileSystemFlags`, `NSFileProviderTypeAndCreator`, create / delete / modify / fetch options, `NSFileProviderMaterializationFlags` | 🟡 | 16.0 | `downloadEagerlyAndKeepDownloaded` downloads at sync; the namespace policy, flags and type and creator are carried, not acted on (proposed) |
| `NSFileProviderIncrementalContentFetching`, `NSFileProviderPartialContentFetching`, `NSFileProviderThumbnailing`, `NSFileProviderItemDecorating`, `NSFileProviderSearching` and its search types, `NSFileProviderServicing`, `NSFileProviderServiceSource`, `NSFileProviderService` | 🟡 | 16.0 | declared with Apple's names; isim always fetches whole files and does not ask for thumbnails, decorations, search or services yet (stub) |
| `NSFileProviderKnownFolders`, `NSFileProviderKnownFolderLocations`, `claimKnownFolders` / `releaseKnownFolders`, `NSFileProviderExternalVolumeHandling`, `checkDomainsCanBeStoredOnVolume`, `NSFileProviderVolumeUnsupportedReason`, `NSFileProviderUserInteractionSuppressing`, `NSFileProviderDomainState` | 🟡 | ≤17 | macOS features: declared; known folders fail with `NSFeatureUnsupportedError`, every volume is eligible (stub) |
| testing operations (`NSFileProviderTestingOperation` and its kinds, `listAvailableTestingOperations`, `run(_:)`) | 🟡 | 16.0 | stub: no operations are listed |
| `NSFileProviderExtension` (the non-replicated extension of iOS 11) | 🟡 | ≤17 | stub: declared for apps that subclass it; isim hosts only replicated extensions |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
