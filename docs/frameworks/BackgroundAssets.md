# BackgroundAssets

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 92.0% of Apple's iOS API (184 of 200, exact) · **Rows:** 9: 6 ✅ 3 🟡 · **iOS:** 16.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [BackgroundAssets](https://developer.apple.com/documentation/backgroundassets) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/BackgroundAssets`, the home screen's `system/SpringBoard/SBBackgroundAssets.m`):
  - `BADownloadManager` downloads with URLSession in the app's process (iOS hands downloads to its download daemon);
  - the downloader extension (`com.apple.background-asset-downloader-extension`) runs as a helper process the home
    screen starts, like iOS's system does: once when its app is installed (`.install`), and on `isim bgassets run APP
    install|update|periodic [--manifest URL]` (Apple's `backgroundassets-debug --simulate`). It gets the app's
    `BAManifestURL`, downloaded, and the allowances (`BAEssentialMaxInstallSize`, `BAMaxInstallSize`); its downloads are
    performed and given to it to move into its app group (`BAAppGroupID`);
  - managed asset packs (iOS 26) are hosted by isim's stand-in for Apple's hosting: `isim bgassets pack add APP ID DIR
    [--version N] [--policy essential|prefetch|on-demand] [--language L]`, `pack remove`, `pack list`; `isim bgassets
    local APP` lists the packs on the device. Downloading a pack copies it (with status updates) into the system's
    store, where `url(for:)`, `contents(at:)` and `descriptor(for:)` find its files.
- **Objective-C / C interface:** `sdk-src/Frameworks/BackgroundAssets/BackgroundAssets.h` over the overlay's classes;
  an Objective-C downloader extension names a class implementing `BADownloaderExtension` as its principal class. The
  managed asset packs are Swift only, like Apple's.
- **Versus Apple's Simulator:** essential downloads do not hold back the app's first launch; downloads run while
  their process runs (no download daemon); the system's periodic runs happen only on `isim bgassets run`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `BADownloadManager` (`shared`, `delegate`, `scheduleDownload`, `startForegroundDownload`, `cancel`, `fetchCurrentDownloads`, `currentDownloads`, `withExclusiveControl` (all four)), `BADownloadManagerDelegate` | ✅ | ≤17 | adapted: URLSession in the app; scheduled downloads start after a moment; a duplicate is `downloadAlreadyScheduled`, an essential one from the app `downloadEssentialDownloadNotPermitted`; exclusive control is a file lock the app and its extension share. Tested: test_background_assets (HelloBackgroundAssets) |
| `BADownload` (`identifier`, `uniqueIdentifier`, `state`, `priority`, `isEssential`, `removingEssential()`, `State`, `Priority`), `BAURLDownload` (all initializers), `BAAppExtensionInfo`, `BAContentRequest` | ✅ | ≤17 | NSSecureCoding; the deprecated initializers make non-essential downloads. Tested: test_background_assets |
| `BADownloaderExtension` (Swift and Objective-C), `BADownloaderExtensionConfiguration` | ✅ | ≤17 | adapted: run by the home screen at install and on `isim bgassets run`; essential downloads count against the essential allowance at install (`downloadWouldExceedAllowance`); the extension moves each finished file. Tested: test_background_assets (a Swift extension; the Objective-C principal class path is proposed) |
| `BAErrorCode`, `BAErrorDomain` | ✅ | 17.0 | Apple's codes. Tested: test_background_assets |
| `AssetPackManager` (`shared`, `statusUpdates`, `ensureLocalAvailability`, `checkForUpdates`, `remove`, `status(relativeTo:)`, `localStatus`, `assetPackIsAvailableLocally`, `url(for:)`, `contents(at:)`, `descriptor(for:)`, the deprecated `allAssetPacks`, `assetPack(withID:)`, `status(ofAssetPackWithID:)`), `AssetPack` (`Status`, `download(for:)`), `ManagedBackgroundAssetsError` | ✅ | 26.0 | adapted: the packs isim hosts (`isim bgassets pack add`); status updates while a pack is copied; `checkForUpdates` downloads newer versions and removes packs no longer hosted. Tested: test_asset_packs (HelloAssetPacks, iOS 27) |
| `ManagedDownloaderExtension` (`shouldDownload`), `ManagedDownloaderExtensionConfiguration` | ✅ | 26.0 | adapted: at install the essential and prefetch hosted packs the extension accepts are downloaded; on update the newer versions of local packs. Tested: test_asset_packs |
| `AssetPackManifest` (`assetPacks`, `allDownloads(for:)`, iOS 27: `assetPack(withID:)`, localized packs, languages), `AssetPackManager.manifest` | 🟡 | 26.0 | adapted: the manifest of isim's hosted packs (its own JSON; Apple's App Store format is not documented) |
| iOS 27 languages: `AssetPack.language`, `locallyAvailableLanguages`, `resolvedLanguage`, `reconcilePreferredLanguages()`, the `asLocalizedFor:` file lookups, `BAContentRequest.languageChange`; `ensureLocalAvailability(of:requireLatestVersions:)`, `LocalAvailabilityError` | 🟡 | 27.0 | adapted: packs added with `--language`; the resolved language is the first preferred language a pack has, else the manifest's primary language (proposed: not yet tested) |
| `localVersion(ofAssetPackWithID:)`, `localSize(ofAssetPackWithID:calculationMethod:)`, `SizeCalculationMethod` | 🟡 | 27.2 | the local pack's version and its files' logical or allocated size (proposed: not yet tested) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
16 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`BADownloaderExtension`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw)
- [`func backgroundDownload(BADownload, didReceive: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:didreceive:))
- [`func backgroundDownload(BADownload, didReceive: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:didreceive:)-5vjx7)
- [`func backgroundDownload(BADownload, didReceive: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:didreceive:)-7qfcp)
- [`func backgroundDownload(BADownload, failedWithError: any Error)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:failedwitherror:))
- [`func backgroundDownload(BADownload, failedWithError: any Error)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:failedwitherror:)-5geag)
- [`func backgroundDownload(BADownload, failedWithError: any Error)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:failedwitherror:)-9erie)
- [`func backgroundDownload(BADownload, finishedWithFileURL: URL)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:finishedwithfileurl:))
- [`func backgroundDownload(BADownload, finishedWithFileURL: URL)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:finishedwithfileurl:)-4s70i)
- [`func backgroundDownload(BADownload, finishedWithFileURL: URL)`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/backgrounddownload(_:finishedwithfileurl:)-5cjqw)
- [`func downloads(for: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload>`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/downloads(for:manifesturl:extensioninfo:))
- [`func downloads(for: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload>`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/downloads(for:manifesturl:extensioninfo:)-60zuh)
- [`func downloads(for: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload>`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/downloads(for:manifesturl:extensioninfo:)-7zv3a)
- [`func extensionWillTerminate()`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/extensionwillterminate()-236ac)
- [`func extensionWillTerminate()`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/extensionwillterminate()-236ac)
- [`func extensionWillTerminate()`](https://developer.apple.com/documentation/backgroundassets/badownloaderextension-qwaw/extensionwillterminate()-236ac)

</details>
<!-- /generated:missing -->
