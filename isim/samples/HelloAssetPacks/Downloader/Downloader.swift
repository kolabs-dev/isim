// HelloAssetPacks' downloader extension: a managed one (BackgroundAssets, iOS 26). The system downloads the app's
// essential and prefetch asset packs at install; this extension only turns one down.
import BackgroundAssets
import Foundation

@main
struct PacksDownloader: ManagedDownloaderExtension {
    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        NSLog("baxp should download %@ v%ld: %@", assetPack.id, assetPack.version, assetPack.id == "skipped" ? "no" : "yes")
        return assetPack.id != "skipped"
    }
}
