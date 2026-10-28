// HelloBackgroundAssets' downloader extension (BackgroundAssets, issue #407): the system runs it at install, update and
// periodically. It reads the app's manifest (its own JSON: a base URL and files, some essential) and asks for those
// downloads; each finished file is moved into the app group's Assets folder, where the app finds it.
import Foundation
import BackgroundAssets

let group = "group.dev.isim.samples.hellobackgroundassets"
func log(_ s: String) { NSLog("bax %@", s) }

@main
struct HelloBackgroundAssetsDownloader: BADownloaderExtension {
    struct Manifest: Decodable { struct File: Decodable { let id, path: String; let size: Int; let essential: Bool }; let base: String; let files: [File] }

    func downloads(for request: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload> {
        log("downloads for \(request == .install ? "install" : request == .update ? "update" : "periodic") essential budget=\(extensionInfo.restrictedEssentialDownloadSizeRemaining ?? -1) budget=\(extensionInfo.restrictedDownloadSizeRemaining ?? -1)")
        guard let data = try? Data(contentsOf: manifestURL), let m = try? JSONDecoder().decode(Manifest.self, from: data) else {
            log("no manifest"); return []
        }
        return Set(m.files.map { f in
            BAURLDownload(identifier: f.id, request: URLRequest(url: URL(string: m.base + f.path)!),
                          essential: f.essential && request == .install, fileSize: f.size, applicationGroupIdentifier: group, priority: .default)
        })
    }
    func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL) {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("Assets") else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dst = dir.appendingPathComponent(finishedDownload.identifier + ".bin")
        try? FileManager.default.removeItem(at: dst)
        do { try FileManager.default.moveItem(at: fileURL, to: dst); log("finished \(finishedDownload.identifier) essential=\(finishedDownload.isEssential)") }
        catch { log("could not move \(finishedDownload.identifier): \(error)") }
    }
    func backgroundDownload(_ failedDownload: BADownload, failedWithError error: any Error) {
        let e = error as NSError
        log("failed \(failedDownload.identifier) \(e.domain)/\(e.code)")
    }
}
