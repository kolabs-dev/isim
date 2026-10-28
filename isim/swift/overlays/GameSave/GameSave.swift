// isim GameSave (self-authored, iOS API names; issue #393): game saves synced through iCloud, adapted. isim has no
// iCloud, so the isim devices on this computer share one directory as the "cloud": $ISIM_GAMESAVE (default
// ~/.local/share/isim-gamesave). Nothing is sent to Apple.
//
//   <cloud>/<container>/meta.json        the latest uploaded version: {version, modified, device, deviceID}
//   <cloud>/<container>/files/           its files
//   <app>/Library/Application Support/GameSave/<container>/data/      the app's local copy (the directory it opens)
//   <app>/Library/Application Support/GameSave/<container>/base.json  the version the local copy came from, and a
//                                                                      manifest of its files then (changes since: an upload)
//
// Opening a directory syncs it: a newer cloud version replaces an unchanged local copy; local changes are uploaded when
// the cloud has not moved on (triggerPendingUpload, finishSyncing, close); when both changed, the directory is
// conflicted and offers both versions until the app picks one. The `gamesave offline|online|status` script command
// takes the device off the network (ISIM_GAMESAVE_OFFLINE=1 at launch); ISIM_GAMESAVE_ACCOUNT=none signs it out of
// iCloud (the directory is local only).
import Foundation
import UIKit
import Observation

public let GameSaveErrorDomain = "GameSaveErrorDomain"

// MARK: - Objective-C classes (GameSave.h)

@objc public enum GSSyncState: Int, Sendable {
    case ready = 0
    case offline = 1
    case local = 2
    case syncing = 3
    case conflicted = 4
    case error = 5
    case closed = 6
}

/// One version of a synced directory: the local copy or the one in iCloud.
@objc(GSSyncedDirectoryVersion) public final class GSSyncedDirectoryVersion: NSObject, @unchecked Sendable {
    @objc public let url: URL
    @objc public let isLocal: Bool
    @objc public let localizedNameOfSavingComputer: String
    @objc public let modifiedDate: Date
    init(url: URL, isLocal: Bool, savedBy: String, modified: Date) {
        self.url = url; self.isLocal = isLocal; localizedNameOfSavingComputer = savedBy; modifiedDate = modified
    }
    public override var description: String {
        "<GSSyncedDirectoryVersion \(isLocal ? "local" : "iCloud") from \(localizedNameOfSavingComputer), \(modifiedDate)>"
    }
}

/// A synced directory's state: where it is, its conflicting versions, or its error.
@objc(GSSyncedDirectoryState) public final class GSSyncedDirectoryState: NSObject, @unchecked Sendable {
    @objc public let state: GSSyncState
    @objc public let url: URL?
    @objc public let conflictedVersions: [GSSyncedDirectoryVersion]?
    @objc public let error: (any Error)?
    init(_ state: GSSyncState, url: URL? = nil, versions: [GSSyncedDirectoryVersion]? = nil, error: (any Error)? = nil) {
        self.state = state; self.url = url; conflictedVersions = versions; self.error = error
    }
    public override var description: String {
        let names = ["ready", "offline", "local", "syncing", "conflicted", "error", "closed"]
        return "<GSSyncedDirectoryState \(names[state.rawValue])\(url.map { " \($0.path)" } ?? "")>"
    }
}

/// A directory of game saves, synced with the player's other devices.
@objc(GSSyncedDirectory) public final class GSSyncedDirectory: NSObject, @unchecked Sendable {
    /// the state (key-value observable)
    @objc public private(set) dynamic var directoryState: GSSyncedDirectoryState
    let container: String
    let localRoot: URL
    var dataURL: URL { localRoot.appendingPathComponent("data", isDirectory: true) }
    var waiters: [() -> Void] = []
    var observer: NSObjectProtocol?

    init(container: String) {
        self.container = container
        localRoot = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/GameSave", isDirectory: true)
            .appendingPathComponent(container, isDirectory: true)
        directoryState = GSSyncedDirectoryState(.syncing)
        super.init()
        observer = NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { [weak self] n in
            guard let t = n.object as? String, t.hasPrefix("gamesave") else { return }
            self?._networkChanged()
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    /// Opens the directory of an iCloud container (nil: the app's default container, iCloud.<bundle identifier>) and
    /// starts syncing it.
    @objc(openForContainerIdentifier:)
    public class func open(forContainerIdentifier containerIdentifier: String?) -> GSSyncedDirectory {
        let d = GSSyncedDirectory(container: containerIdentifier ?? "iCloud.\(Bundle.main.bundleIdentifier ?? "app")")
        NSLog("isim GameSave: opening %@", d.container)
        _GSQueue.async { d._sync() }
        return d
    }

    /// Waits until the directory is no longer syncing (pending changes uploaded). isim shows no progress window.
    @objc(finishSyncing:completionHandler:)
    public func finishSyncing(_ statusDisplay: UIWindow, completionHandler: @escaping @Sendable () -> Void) {
        finishSyncing(completionHandler: completionHandler)
    }
    @objc(finishSyncingWithCompletionHandler:)
    public func finishSyncing(completionHandler: @escaping @Sendable () -> Void) {
        _GSQueue.async {
            if self._current.state == .ready { _ = self._upload() }
            if self._current.state == .syncing { self.waiters.append(completionHandler) }
            else { DispatchQueue.main.async(execute: completionHandler) }
        }
    }

    /// Keeps `version` and discards the other: it becomes the local copy and is uploaded.
    @objc(resolveConflictsWithVersion:)
    public func resolveConflicts(with version: GSSyncedDirectoryVersion) {
        _GSQueue.async {
            guard self._current.state == .conflicted else { return }
            NSLog("isim GameSave: %@: keeping the %@ version", self.container, version.isLocal ? "local" : "iCloud")
            if !version.isLocal { _GS.replace(self.dataURL, with: version.url) }
            let cloud = _GS.readMeta(self.container)
            self._saveBase(version: cloud?.version ?? 0)
            if version.isLocal { self._markDirty() }
            self._set(GSSyncedDirectoryState(.ready, url: self.dataURL))
            _ = self._upload()
            for v in self._current.conflictedVersions ?? [] { try? FileManager.default.removeItem(at: v.url) }
        }
    }

    /// Uploads the local changes now; the handler gets whether they reached iCloud (or there were none).
    @objc(triggerPendingUploadWithCompletionHandler:)
    public func triggerPendingUpload(completionHandler: @escaping @Sendable (Bool) -> Void) {
        _GSQueue.async {
            let ok = self._current.state == .ready ? self._upload() : false
            DispatchQueue.main.async { completionHandler(ok) }
        }
    }

    /// Uploads pending changes and closes the directory: the app must not write to it any more.
    @objc public func close() {
        _GSQueue.sync {
            if _current.state == .ready { _ = _upload() }
            _set(GSSyncedDirectoryState(.closed))
            NSLog("isim GameSave: %@ closed", container)
        }
    }

    // MARK: syncing (on _GSQueue)

    var offline: Bool { _GS.offline }

    /// the state as the sync queue knows it (directoryState follows on the main queue)
    var _current = GSSyncedDirectoryState(.syncing)
    func _set(_ s: GSSyncedDirectoryState) {
        _current = s
        DispatchQueue.main.async {
            self.directoryState = s
            NSLog("isim GameSave: %@ %@", self.container, s.description)
        }
        if s.state != .syncing { let w = waiters; waiters = []; DispatchQueue.main.async { w.forEach { $0() } } }
    }

    func _sync() {
        try? FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        if _GS.signedOut { _set(GSSyncedDirectoryState(.local, url: dataURL)); return }
        if offline { _set(GSSyncedDirectoryState(.offline, url: dataURL)); return }
        let base = _loadBase()
        let cloud = _GS.readMeta(container)
        let dirty = _GS.manifest(dataURL) != base.manifest
        guard let cloud, cloud.version > base.version else {
            _set(GSSyncedDirectoryState(.ready, url: dataURL))
            if dirty { _ = _upload() }
            return
        }
        if !dirty {
            // a newer version from another device: download it
            _GS.replace(dataURL, with: _GS.cloudFiles(container))
            _saveBase(version: cloud.version)
            NSLog("isim GameSave: %@ downloaded version %ld from %@", container, cloud.version, cloud.device)
            _set(GSSyncedDirectoryState(.ready, url: dataURL))
            return
        }
        // both changed: offer both versions (copies the app can read)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GameSave-\(UUID().uuidString)", isDirectory: true)
        let local = tmp.appendingPathComponent("local", isDirectory: true), remote = tmp.appendingPathComponent("iCloud", isDirectory: true)
        _GS.replace(local, with: dataURL)
        _GS.replace(remote, with: _GS.cloudFiles(container))
        let versions = [
            GSSyncedDirectoryVersion(url: local, isLocal: true, savedBy: _GS.deviceName, modified: _GS.latestModification(dataURL)),
            GSSyncedDirectoryVersion(url: remote, isLocal: false, savedBy: cloud.device, modified: cloud.modified),
        ]
        NSLog("isim GameSave: %@ conflicted: local changes and version %ld from %@", container, cloud.version, cloud.device)
        _set(GSSyncedDirectoryState(.conflicted, versions: versions))
    }

    /// uploads the local copy when it changed; false when the cloud moved on (conflict) or the device is offline
    func _upload() -> Bool {
        let base = _loadBase()
        let manifest = _GS.manifest(dataURL)
        guard manifest != base.manifest || base.forced else { return true }
        if offline || _GS.signedOut { return false }
        return _GS.locked(container) {
            let cloud = _GS.readMeta(container)
            if let cloud, cloud.version > base.version {
                NSLog("isim GameSave: %@: iCloud has a newer version; not uploading", container)
                _GSQueue.async { self._sync() }
                return false
            }
            let v = (cloud?.version ?? 0) + 1
            _GS.replace(_GS.cloudFiles(container), with: dataURL)
            _GS.writeMeta(container, version: v)
            _saveBase(version: v)
            NSLog("isim GameSave: %@ uploaded version %ld", container, v)
            return true
        }
    }

    func _networkChanged() {
        _GSQueue.async {
            switch self._current.state {
            case .offline where !self.offline: self._set(GSSyncedDirectoryState(.syncing)); self._sync()
            case .ready where self.offline: self._set(GSSyncedDirectoryState(.offline, url: self.dataURL))
            default: break
            }
        }
    }

    struct Base { var version: Int; var manifest: [String: String]; var forced: Bool }
    var baseURL: URL { localRoot.appendingPathComponent("base.json") }
    func _loadBase() -> Base {
        guard let d = try? Data(contentsOf: baseURL), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else {
            return Base(version: 0, manifest: [:], forced: false)
        }
        return Base(version: o["version"] as? Int ?? 0, manifest: o["manifest"] as? [String: String] ?? [:], forced: o["forced"] as? Bool ?? false)
    }
    func _saveBase(version: Int) {
        let o: [String: Any] = ["version": version, "manifest": _GS.manifest(dataURL)]
        try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]).write(to: baseURL, options: .atomic)
    }
    /// the local copy must be uploaded even if it equals the base (a local version kept over the cloud's)
    func _markDirty() {
        var o: [String: Any] = ["version": _loadBase().version, "manifest": _GS.manifest(dataURL)]
        o["forced"] = true
        try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]).write(to: baseURL, options: .atomic)
    }
}

let _GSQueue = DispatchQueue(label: "isim.GameSave")

enum _GS {
    static func env(_ name: String) -> String? {
        guard let v = ProcessInfo.processInfo.environment[name], !v.isEmpty else { return nil }
        return v
    }
    static var home: String { env("HOME") ?? "/tmp" }
    static let root = URL(fileURLWithPath: env("ISIM_GAMESAVE") ?? (home as NSString).appendingPathComponent(".local/share/isim-gamesave"), isDirectory: true)
    nonisolated(unsafe) static var _offline: Bool = env("ISIM_GAMESAVE_OFFLINE") == "1"
    static var offline: Bool { _offline }
    static var signedOut: Bool { env("ISIM_GAMESAVE_ACCOUNT") == "none" }
    static var deviceName: String {
        let d = UIDevice.current
        let sel = NSSelectorFromString("_isim_deviceName")
        return d.responds(to: sel) ? (d.perform(sel)?.takeUnretainedValue() as? String ?? d.name) : d.name
    }

    static func containerURL(_ c: String) -> URL { root.appendingPathComponent(c, isDirectory: true) }
    static func cloudFiles(_ c: String) -> URL { containerURL(c).appendingPathComponent("files", isDirectory: true) }

    struct Meta { let version: Int; let modified: Date; let device: String }
    static func readMeta(_ c: String) -> Meta? {
        guard let d = try? Data(contentsOf: containerURL(c).appendingPathComponent("meta.json")),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let v = o["version"] as? Int else { return nil }
        return Meta(version: v, modified: Date(timeIntervalSince1970: o["modified"] as? Double ?? 0), device: o["device"] as? String ?? "iPhone")
    }
    static func writeMeta(_ c: String, version: Int) {
        let o: [String: Any] = ["version": version, "modified": Date().timeIntervalSince1970, "device": deviceName]
        try? JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]).write(to: containerURL(c).appendingPathComponent("meta.json"), options: .atomic)
    }

    /// the files under `dir`: relative path -> size and a hash of the contents
    static func manifest(_ dir: URL) -> [String: String] {
        var out: [String: String] = [:]
        let base = dir.standardizedFileURL.path
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return out }
        for case let u as URL in e where (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            guard let d = try? Data(contentsOf: u) else { continue }
            var h: UInt64 = 0xcbf29ce484222325
            for b in d { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            out[String(u.standardizedFileURL.path.dropFirst(base.count))] = "\(d.count):\(String(h, radix: 16))"
        }
        return out
    }
    static func latestModification(_ dir: URL) -> Date {
        var latest = Date(timeIntervalSince1970: 0)
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
        while let u = e?.nextObject() as? URL {
            if let m = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, m > latest { latest = m }
        }
        return latest
    }
    /// makes `dst` a copy of `src` (an empty directory when src does not exist)
    static func replace(_ dst: URL, with src: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = dst.deletingLastPathComponent().appendingPathComponent(".\(dst.lastPathComponent).isim-tmp-\(UUID().uuidString)")
        if fm.fileExists(atPath: src.path) { try? fm.copyItem(at: src, to: tmp) } else { try? fm.createDirectory(at: tmp, withIntermediateDirectories: true) }
        try? fm.removeItem(at: dst)
        try? fm.moveItem(at: tmp, to: dst)
    }
    /// runs `body` holding the container's lock (a directory; older than 10 s: stale)
    static func locked<T>(_ c: String, _ body: () -> T) -> T {
        let dir = containerURL(c)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lock = dir.appendingPathComponent("lock").path
        let start = Date()
        while mkdir(lock, 0o755) != 0 {
            if let a = try? FileManager.default.attributesOfItem(atPath: lock), let m = a[.modificationDate] as? Date, Date().timeIntervalSince(m) > 10 {
                rmdir(lock); continue
            }
            if Date().timeIntervalSince(start) > 10 { break }
            usleep(5000)
        }
        defer { rmdir(lock) }
        return body()
    }
}

/// the `gamesave` script command: offline, online, status
@_cdecl("isim_gamesave_command")
public func _isim_gamesave_command(_ args: UnsafePointer<CChar>) {
    let w = String(cString: args).split(separator: " ").map(String.init)
    switch w.first {
    case "offline": _GS._offline = true; NSLog("isim GameSave: offline")
    case "online": _GS._offline = false; NSLog("isim GameSave: online")
    default: NSLog("isim GameSave: %@, iCloud %@", _GS.offline ? "offline" : "online", _GS.signedOut ? "signed out" : "signed in")
    }
    NotificationCenter.default.post(name: Notification.Name("_IsimSystemEvent"), object: "gamesave" as NSString)
}

// MARK: - Swift

/// A directory of game saves, synced with the player's other devices through iCloud.
public final class GameSaveSyncedDirectory: Observable, @unchecked Sendable {
    public enum State: Sendable {
        /// the directory is synced and can be read and written
        case ready(URL)
        /// the device is offline: the local copy can be used, changes upload later
        case offline(URL)
        /// iCloud is not available (signed out): the directory is only on this device
        case local(URL)
        /// syncing with iCloud: wait
        case syncing
        /// this device and another changed the saves: pick a version with resolveConflicts(with:)
        case conflicted(versions: [Version])
        case error(any Error)
        /// closed with close()
        case closed
    }

    /// One version of the directory: the local copy or the one in iCloud.
    public final class Version: @unchecked Sendable {
        let _gs: GSSyncedDirectoryVersion
        init(_ v: GSSyncedDirectoryVersion) { _gs = v }
        public var url: URL { _gs.url }
        public var isLocal: Bool { _gs.isLocal }
        public var localizedNameOfSavingComputer: String { _gs.localizedNameOfSavingComputer }
        public var modifiedDate: Date { _gs.modifiedDate }
    }

    let _gs: GSSyncedDirectory
    private let _registrar = ObservationRegistrar()
    private var _state: State = .syncing
    private var _kvo: NSKeyValueObservation?

    init(_ gs: GSSyncedDirectory) {
        _gs = gs
        _state = Self._state(gs.directoryState)
        _kvo = gs.observe(\.directoryState, options: [.new]) { [weak self] gs, _ in
            guard let self else { return }
            let s = Self._state(gs.directoryState)
            self._registrar.withMutation(of: self, keyPath: \.state) { self._state = s }
        }
    }
    static func _state(_ s: GSSyncedDirectoryState) -> State {
        switch s.state {
        case .ready: return s.url.map(State.ready) ?? .syncing
        case .offline: return s.url.map(State.offline) ?? .syncing
        case .local: return s.url.map(State.local) ?? .syncing
        case .syncing: return .syncing
        case .conflicted: return .conflicted(versions: (s.conflictedVersions ?? []).map(Version.init))
        case .error: return .error(s.error ?? NSError(domain: GameSaveErrorDomain, code: 0))
        case .closed: return .closed
        }
    }

    /// Opens the directory of an iCloud container (nil: the app's default container) and starts syncing it.
    public class func openDirectory(containerIdentifier: String?) -> GameSaveSyncedDirectory {
        GameSaveSyncedDirectory(GSSyncedDirectory.open(forContainerIdentifier: containerIdentifier))
    }
    /// the state (observable)
    public var state: State {
        _registrar.access(self, keyPath: \.state)
        return _state
    }
    /// Waits until syncing is done (pending changes uploaded).
    public func finishSyncing() async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in _gs.finishSyncing { k.resume() } }
    }
    /// Waits until syncing is done; Apple shows its progress in the window (isim: no progress UI).
    public func finishSyncing(statusDisplay: UIWindow) async { await finishSyncing() }
    /// Keeps `version`, discarding the other.
    public func resolveConflicts(with version: Version) { _gs.resolveConflicts(with: version._gs) }
    /// Uploads the local changes now; whether they reached iCloud.
    public func triggerPendingUpload() async -> Bool {
        await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in _gs.triggerPendingUpload { k.resume(returning: $0) } }
    }
    /// Uploads pending changes and closes the directory.
    public func close() { _gs.close() }
}
