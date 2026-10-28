// isim BackgroundAssets: the downloader extension (com.apple.background-asset-downloader-extension). The home screen
// runs it as a helper process (like the other extension helpers) when its app is installed (.install) and on
// `isim bgassets run APP install|update|periodic [--manifest URL]` (Apple's backgroundassets-debug --simulate). The
// process gets ISIM_EXTENSION_REQUEST, a plist (request, manifestURL, the allowances, out); it downloads the app's
// BAManifestURL, asks the extension for its downloads, performs them with URLSession (asset packs: from isim's asset
// pack store, AssetPacks.swift) and gives each result to the extension, which moves the file into its app group.
// Essential downloads count against BAEssentialMaxInstallSize, the others against BAMaxInstallSize. The results are
// written to `out` for the home screen. Swift extensions run through BADownloaderExtension.main(); Objective-C ones
// name a class conforming to the BADownloaderExtension protocol (NSExtensionPrincipalClass).
import Foundation
import ExtensionFoundation

@MainActor @preconcurrency public protocol BADownloaderExtensionConfiguration: AppExtensionConfiguration {}
@available(iOS 26.0, *)
@MainActor @preconcurrency public protocol ManagedDownloaderExtensionConfiguration: BADownloaderExtensionConfiguration {}

/// the configuration a downloader extension gets (it accepts the system's connection)
public struct _BADownloaderConfiguration: BADownloaderExtensionConfiguration, @unchecked Sendable {
    public init() {}
    nonisolated public func accept(connection: NSXPCConnection) -> Bool { true }
}
@available(iOS 26.0, *)
extension _BADownloaderConfiguration: ManagedDownloaderExtensionConfiguration {}

public protocol BADownloaderExtension: AppExtension {
    func downloads(for request: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload>
    func backgroundDownload(_ download: BADownload, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
    func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL)
    func backgroundDownload(_ failedDownload: BADownload, failedWithError error: any Error)
    @available(iOS, introduced: 16.1, deprecated: 16.4, message: "the extension's process ends after its work without notice")
    func extensionWillTerminate()
}
extension BADownloaderExtension {
    public var configuration: _BADownloaderConfiguration { _BADownloaderConfiguration() }
    public func downloads(for request: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload> { [] }
    public func backgroundDownload(_ download: BADownload, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
    public func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL) {}
    public func backgroundDownload(_ failedDownload: BADownload, failedWithError error: any Error) {}
    public func extensionWillTerminate() {}
    /// the extension's entry point (@main): the system's download host
    public static func main() throws { MainActor.assumeIsolated { _BAExtensionHost.run(Self()) } }
}

/// the Objective-C protocol of downloader extensions (the principal class implements it)
@objc(BADownloaderExtension) public protocol _BADownloaderExtensionObjC: NSObjectProtocol {
    @objc(downloadsForRequest:manifestURL:extensionInfo:)
    optional func downloads(for request: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload>
    @objc(backgroundDownload:didReceiveChallenge:completionHandler:)
    optional func backgroundDownload(_ download: BADownload, didReceive challenge: URLAuthenticationChallenge,
                                     completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    @objc(backgroundDownload:failedWithError:) optional func backgroundDownload(_ failedDownload: BADownload, failedWithError error: any Error)
    @objc(backgroundDownload:finishedWithFileURL:) optional func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL)
    @objc(extensionWillTerminate) optional func extensionWillTerminate()
}
/// an Objective-C principal class, run like a Swift extension
struct _BAObjCExtension: BADownloaderExtension {
    nonisolated(unsafe) static var instance: (any _BADownloaderExtensionObjC)?
    init() {}
    var o: (any _BADownloaderExtensionObjC)? { Self.instance }
    func downloads(for request: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload> {
        o?.downloads?(for: request, manifestURL: manifestURL, extensionInfo: extensionInfo) ?? []
    }
    func backgroundDownload(_ download: BADownload, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let o, o.responds(to: #selector(_BADownloaderExtensionObjC.backgroundDownload(_:didReceive:completionHandler:))) else { return (.performDefaultHandling, nil) }
        let u = _UncheckedSendable(o)
        return await withCheckedContinuation { k in
            u.value.backgroundDownload?(download, didReceive: challenge) { d, c in k.resume(returning: (d, c)) }
        }
    }
    func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL) { o?.backgroundDownload?(finishedDownload, finishedWithFileURL: fileURL) }
    func backgroundDownload(_ failedDownload: BADownload, failedWithError error: any Error) { o?.backgroundDownload?(failedDownload, failedWithError: error) }
}
/// NSExtensionMain (UIKit) for an extension without a Swift @main: its principal class
@_cdecl("isim_ba_extension_main")
public func _isim_ba_extension_main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    let name = (Bundle.main.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPrincipalClass"] as? String ?? ""
    guard let cls = NSClassFromString(name) as? NSObject.Type, let o = cls.init() as? any _BADownloaderExtensionObjC else {
        NSLog("isim BackgroundAssets: the downloader extension has no Swift @main and its NSExtensionPrincipalClass '%@' does not implement BADownloaderExtension", name)
        return 1
    }
    _BAObjCExtension.instance = o
    MainActor.assumeIsolated { _BAExtensionHost.run(_BAObjCExtension()) }
}

// MARK: - the host

@MainActor enum _BAExtensionHost {
    struct Result { var identifier: String; var state: String; var error: String? }
    static func run<E: BADownloaderExtension>(_ e: E) -> Never {
        Task { @MainActor in
            let code = await perform(e)
            fflush(nil)
            exit(code)
        }
        RunLoop.main.run()
        exit(0)
    }
    static func perform<E: BADownloaderExtension>(_ e: E) async -> Int32 {
        guard let rp = ProcessInfo.processInfo.environment["ISIM_EXTENSION_REQUEST"], let req = NSDictionary(contentsOfFile: rp) as? [String: Any] else {
            NSLog("isim BackgroundAssets: the downloader extension runs when the system asks (no ISIM_EXTENSION_REQUEST)")
            return 1
        }
        let names: [String: BAContentRequest] = ["install": .install, "update": .update, "periodic": .periodic]
        var kind = names[req["request"] as? String ?? ""] ?? .periodic
        if #available(iOS 27.0, *), req["request"] as? String == "languageChange" { kind = .languageChange }
        let budget = req["budget"] as? Int, essentialBudget = req["essentialBudget"] as? Int
        let info = BAAppExtensionInfo(restricted: budget, essential: essentialBudget)
        NSLog("isim BackgroundAssets: downloader extension for %@ (%@)", req["bundle"] as? String ?? "?", req["request"] as? String ?? "?")
        /* the manifest the system downloads for the extension */
        let manifest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("isim-ba-manifest-\(UUID().uuidString).json")
        if let s = req["manifestURL"] as? String, let u = URL(string: s) {
            do {
                let (data, response) = try await URLSession.shared.data(from: u)
                if let h = response as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw _baError(.downloadFailedToStart, "HTTP status \(h.statusCode)") }
                try data.write(to: manifest)
                NSLog("isim BackgroundAssets: manifest %@ (%ld bytes)", s, data.count)
            } catch {
                NSLog("isim BackgroundAssets: cannot download the manifest %@: %@", s, "\(error)")
                write([], to: req["out"] as? String, manifestError: "\(error)")
                return 0
            }
        } else {
            FileManager.default.createFile(atPath: manifest.path, contents: Data())
        }
        let downloads = e.downloads(for: kind, manifestURL: manifest, extensionInfo: info)
        NSLog("isim BackgroundAssets: the extension asked for %ld download(s)", downloads.count)
        var results: [Result] = []
        var essentialLeft = essentialBudget ?? Int.max, left = budget ?? Int.max
        var urlDownloads: [BAURLDownload] = []
        for d in downloads.sorted(by: { $0._priority > $1._priority || ($0._priority == $1._priority && $0.identifier < $1.identifier) }) {
            if #available(iOS 26.0, *), let p = d as? _BAAssetPackDownload {
                do {
                    try await AssetPackManager.shared._download(p.pack)
                    results.append(Result(identifier: d.identifier, state: "finished"))
                    e.backgroundDownload(d, finishedWithFileURL: AssetPackManager._localDir(p.pack.id))
                } catch {
                    results.append(Result(identifier: d.identifier, state: "failed", error: "\(error)"))
                    e.backgroundDownload(d, failedWithError: error)
                }
                continue
            }
            guard let u = d as? BAURLDownload else { continue }
            let size = u.fileSize
            if u._essential && kind == .install {
                if size > essentialLeft {
                    let err = _baError(.downloadWouldExceedAllowance, "\(u.identifier) would exceed the essential download allowance")
                    NSLog("isim BackgroundAssets: %@", err.localizedDescription)
                    results.append(Result(identifier: d.identifier, state: "failed", error: "BAErrorDomain/\(err.code)"))
                    e.backgroundDownload(d, failedWithError: err)
                    continue
                }
                essentialLeft -= size
            } else {
                if size > left {
                    let err = _baError(.downloadWouldExceedAllowance, "\(u.identifier) would exceed the download allowance")
                    results.append(Result(identifier: d.identifier, state: "failed", error: "BAErrorDomain/\(err.code)"))
                    e.backgroundDownload(d, failedWithError: err)
                    continue
                }
                left -= size
            }
            urlDownloads.append(u)
        }
        /* the URL downloads, one at a time in priority order (essential first at install) */
        for u in urlDownloads.sorted(by: { ($0._essential ? 1 : 0, $0._priority) > ($1._essential ? 1 : 0, $1._priority) }) {
            let r: Result = await withCheckedContinuation { (k: CheckedContinuation<Result, Never>) in
                var s = _BATransfers.Sink()
                let box = _UncheckedSendable(e)
                s.challenge = { d, c, handler in
                    Task { @MainActor in let (disp, cred) = await box.value.backgroundDownload(d, didReceive: c); handler(disp, cred) }
                }
                s.finished = { d, url in
                    NSLog("isim BackgroundAssets: extension download %@ finished", d.identifier)
                    DispatchQueue.main.sync { MainActor.assumeIsolated { box.value.backgroundDownload(d, finishedWithFileURL: url) } }
                    k.resume(returning: Result(identifier: d.identifier, state: "finished"))
                }
                s.failed = { d, err in
                    NSLog("isim BackgroundAssets: extension download %@ failed: %@", d.identifier, "\(err)")
                    DispatchQueue.main.sync { MainActor.assumeIsolated { box.value.backgroundDownload(d, failedWithError: err) } }
                    let ns = err as NSError
                    k.resume(returning: Result(identifier: d.identifier, state: "failed", error: "\(ns.domain)/\(ns.code)"))
                }
                let t = _BATransfers(s)
                _BAExtensionHost.keep = t
                t.start(u)
            }
            results.append(r)
        }
        write(results, to: req["out"] as? String, manifestError: nil)
        return 0
    }
    static var keep: _BATransfers?
    static func write(_ results: [Result], to out: String?, manifestError: String?) {
        guard let out else { return }
        var d: [String: Any] = ["downloads": results.map { r -> [String: Any] in
            var x: [String: Any] = ["identifier": r.identifier, "state": r.state]
            if let e = r.error { x["error"] = e }
            return x
        }]
        if let m = manifestError { d["manifestError"] = m }
        (d as NSDictionary).write(toFile: out, atomically: true)
    }
}
