// isim FileProvider: the system side (what iOS's fileproviderd does), adapted.
//
// The device's domains are listed in <isim data>/Library/isim/FileProvider/domains.json (NSFileProviderManager.add
// writes them, with the app's extension). Each has a replica, <…>/FileProvider/Domains/<extension>/<domain>/: the
// domain's items as folders and files. A file is a placeholder of the item's size until something opens it
// (materialize: the extension's fetchContents), unless the item's contentPolicy downloads it eagerly. The replica's
// state (item identifiers, versions, which files are placeholders, the sync anchor) is kept beside it in
// <…>/FileProvider/State/<extension>/<domain>.json.
//
// Syncing a domain (the picker opening it, signalEnumerator, getUserVisibleURL…) first sends local changes to the
// extension: a new file or folder in the replica is createItem, a changed file modifyItem (contents), a removed one
// deleteItem (a move is a deletion and a creation). Then it takes the extension's changes: enumerateChanges on the
// working set from the last sync anchor, or (no anchor, the anchor expired, no enumerateChanges) a full enumeration
// from the root container. The extension runs in the process that syncs (one instance per domain and process), not in
// a process of its own; two processes syncing the same domain take turns (a lock file).
import Foundation
import UniformTypeIdentifiers

// the container identifiers (their C constants live in FileProvider.framework, which links after this overlay)
let _fpRoot = NSFileProviderItemIdentifier("NSFileProviderRootContainerItemIdentifier")
let _fpWorkingSet = NSFileProviderItemIdentifier("NSFileProviderWorkingSetContainerItemIdentifier")

// MARK: - the device's domains

struct _FPRecord: Codable, Equatable {
    var app: String                 // the provider app's bundle identifier
    var appPath: String
    var provider: String            // the extension's bundle identifier (providerIdentifier)
    var extensionPath: String
    var executable: String
    var identifier: String
    var displayName: String
    var pathRelative: String
    var hidden: Bool
    var disconnected: Bool
    var userEnabled: Bool
    var key: String { "\(provider)/\(identifier)" }
}

enum _FPHost {
    static var data: String {
        ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? ((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    static var root: String { (data as NSString).appendingPathComponent("Library/isim/FileProvider") }
    static var registryPath: String { (root as NSString).appendingPathComponent("domains.json") }
    static func safe(_ s: String) -> String { s.replacingOccurrences(of: "/", with: "_") }
    static func replicaPath(_ r: _FPRecord) -> String { (root as NSString).appendingPathComponent("Domains/\(safe(r.provider))/\(safe(r.identifier))") }
    static func statePath(_ r: _FPRecord) -> String { (root as NSString).appendingPathComponent("State/\(safe(r.provider))/\(safe(r.identifier)).json") }
    static func dir(_ kind: String, _ r: _FPRecord) -> URL {
        let p = (root as NSString).appendingPathComponent("\(kind)/\(safe(r.provider))/\(safe(r.identifier))")
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        return URL(fileURLWithPath: p, isDirectory: true)
    }

    static let lock = NSLock()
    static func records() -> [_FPRecord] {
        guard let d = FileManager.default.contents(atPath: registryPath) else { return [] }
        return (try? JSONDecoder().decode([_FPRecord].self, from: d)) ?? []
    }
    static func save(_ rs: [_FPRecord]) {
        try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? e.encode(rs) { FileManager.default.createFile(atPath: registryPath, contents: d) }
    }
    static func update(_ body: (inout [_FPRecord]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var rs = records()
        body(&rs)
        save(rs)
    }
    /// the record whose replica is `path` or holds it
    static func record(containing path: String) -> _FPRecord? {
        let p = (path as NSString).standardizingPath
        return records().first { let r = replicaPath($0); return p == r || p.hasPrefix(r + "/") }
    }

    /// the app's file provider extension: { bundle id, path, executable }
    static func providerExtension(appPath: String = Bundle.main.bundlePath) -> (id: String, path: String, exe: String)? {
        let plugins = (appPath as NSString).appendingPathComponent("PlugIns")
        for n in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where n.hasSuffix(".appex") {
            let p = (plugins as NSString).appendingPathComponent(n)
            guard let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                  let ext = info["NSExtension"] as? [String: Any], ext["NSExtensionPointIdentifier"] as? String == "com.apple.fileprovider-nonui" else { continue }
            let exe = (p as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? (n as NSString).deletingPathExtension)
            return (info["CFBundleIdentifier"] as? String ?? n, p, exe)
        }
        return nil
    }

    static func domain(_ r: _FPRecord) -> NSFileProviderDomain {
        let d = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier(r.identifier), displayName: r.displayName,
                                     pathRelativeToDocumentStorage: r.pathRelative)
        d.isHidden = r.hidden
        d._disconnected = r.disconnected
        d._userEnabled = r.userEnabled
        return d
    }

    // the replicas this process has opened, by record key
    nonisolated(unsafe) static var replicas: [String: _FPReplica] = [:]
    static func replica(_ r: _FPRecord) -> _FPReplica {
        lock.lock(); defer { lock.unlock() }
        if let x = replicas[r.key] { return x }
        let x = _FPReplica(r)
        replicas[r.key] = x
        return x
    }
    static func forget(_ r: _FPRecord) -> _FPReplica? {
        lock.lock(); defer { lock.unlock() }
        return replicas.removeValue(forKey: r.key)
    }

    static func log(_ s: String) { NSLog("isim FileProvider: %@", s) }
    static func changed(_ r: _FPRecord) {
        let p = replicaPath(r)
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("_IsimFileProviderChanged"), object: p) }
    }
}

// MARK: - items isim makes (templates for createItem / modifyItem, local listings)

final class _FPLocalItem: NSObject, NSFileProviderItemProtocol, @unchecked Sendable {
    let itemIdentifier: NSFileProviderItemIdentifier
    let parentItemIdentifier: NSFileProviderItemIdentifier
    let filename: String
    let contentType: UTType
    let documentSize: NSNumber?
    let creationDate: Date?
    let contentModificationDate: Date?
    let itemVersion: NSFileProviderItemVersion
    var capabilities: NSFileProviderItemCapabilities {
        [.allowsReading, .allowsWriting, .allowsRenaming, .allowsReparenting, .allowsDeleting, .allowsAddingSubItems, .allowsContentEnumerating]
    }
    init(id: NSFileProviderItemIdentifier, parent: NSFileProviderItemIdentifier, name: String, folder: Bool, size: Int64?, created: Date?, modified: Date?,
         version: NSFileProviderItemVersion) {
        itemIdentifier = id; parentItemIdentifier = parent; filename = name
        contentType = folder ? .folder : (UTType(filenameExtension: (name as NSString).pathExtension) ?? .data)
        documentSize = folder ? nil : size.map { NSNumber(value: $0) }
        creationDate = created; contentModificationDate = modified; itemVersion = version
    }
}

// MARK: - enumeration helpers

final class _FPEnumerationObserver: NSObject, NSFileProviderEnumerationObserver, @unchecked Sendable {
    var items: [NSFileProviderItem] = []
    var finish: ((Result<NSFileProviderPage?, any Error>) -> Void)?
    func didEnumerate(_ updatedItems: [any NSFileProviderItemProtocol]) { items += updatedItems }
    func finishEnumerating(upTo nextPage: NSFileProviderPage?) { let f = finish; finish = nil; f?(.success(nextPage)) }
    func finishEnumeratingWithError(_ error: any Error) { let f = finish; finish = nil; f?(.failure(error)) }
    var suggestedPageSize: Int { 200 }
}

final class _FPChangeObserver: NSObject, NSFileProviderChangeObserver, @unchecked Sendable {
    var updated: [NSFileProviderItem] = []
    var deleted: [NSFileProviderItemIdentifier] = []
    var finish: ((Result<(NSFileProviderSyncAnchor, Bool), any Error>) -> Void)?
    func didUpdate(_ updatedItems: [any NSFileProviderItemProtocol]) { updated += updatedItems }
    func didDeleteItems(withIdentifiers deletedItemIdentifiers: [NSFileProviderItemIdentifier]) { deleted += deletedItemIdentifiers }
    func finishEnumeratingChanges(upTo anchor: NSFileProviderSyncAnchor, moreComing: Bool) { let f = finish; finish = nil; f?(.success((anchor, moreComing))) }
    func finishEnumeratingWithError(_ error: any Error) { let f = finish; finish = nil; f?(.failure(error)) }
    var suggestedBatchSize: Int { 200 }
}

/// whether an item is a folder (its content type, else its child count)
func _fpIsFolder(_ item: NSFileProviderItem) -> Bool {
    if let t = item.contentType { return t.conforms(to: .directory) && !t.conforms(to: .package) }
    if let t = item.typeIdentifier, let u = UTType(t) { return u.conforms(to: .directory) && !u.conforms(to: .package) }
    return (item.childItemCount ?? nil) != nil
}

// MARK: - a replica

struct _FPEntry: Codable {
    var id: String
    var parent: String
    var name: String
    var folder: Bool
    var content: Data
    var metadata: Data
    var size: Int64
    var mtime: Double          // the file's modification time when isim last wrote or synced it
    var dataless: Bool         // a placeholder: its contents have not been fetched
    var eager: Bool
}
struct _FPState: Codable {
    var anchor: Data?
    var version: Int = 0
    var entries: [String: _FPEntry] = [:]

    /// an item's path in the replica, from its parents
    func relPath(_ id: String) -> String? {
        if id == _fpRoot.rawValue { return "" }
        var parts: [String] = []
        var cur = id
        for _ in 0..<256 {
            guard let e = entries[cur] else { return nil }
            parts.append(e.name)
            if e.parent == _fpRoot.rawValue { return parts.reversed().joined(separator: "/") }
            cur = e.parent
        }
        return nil
    }
    func fullPath(_ id: String, root: String) -> String? { relPath(id).map { $0.isEmpty ? root : (root as NSString).appendingPathComponent($0) } }
    func entry(atPath path: String, root: String) -> _FPEntry? {
        let p = (path as NSString).standardizingPath
        return entries.values.first { fullPath($0.id, root: root) == p }
    }
}

actor _FPReplica {
    let record: _FPRecord
    let root: String
    var state: _FPState
    var ext: (any NSFileProviderReplicatedExtension)?
    var lockFD: Int32 = -1

    init(_ r: _FPRecord) {
        record = r
        root = _FPHost.replicaPath(r)
        state = FileManager.default.contents(atPath: _FPHost.statePath(r)).flatMap { try? JSONDecoder().decode(_FPState.self, from: $0) } ?? _FPState()
        try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
    }

    // ---- the extension ----
    func loadedExtension() throws -> any NSFileProviderReplicatedExtension {
        if let e = ext { return e }
        guard dlopen(record.executable, RTLD_NOW) != nil else {
            throw _fpError(.applicationExtensionNotFound, "cannot load \(record.provider): \(String(cString: dlerror()))")
        }
        if let reg = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_bundle_register_extension") {
            unsafeBitCast(reg, to: (@convention(c) (NSString) -> Void).self)(record.extensionPath as NSString)
        }
        let info = NSDictionary(contentsOfFile: (record.extensionPath as NSString).appendingPathComponent("Info.plist")) as? [String: Any]
        let name = (info?["NSExtension"] as? [String: Any])?["NSExtensionPrincipalClass"] as? String ?? ""
        guard let cls = NSClassFromString(name) else {
            throw _fpError(.applicationExtensionNotFound, "\(record.provider): no class \(name.isEmpty ? "(NSExtensionPrincipalClass)" : name)")
        }
        let domain = _FPHost.domain(record)
        let made: any NSFileProviderReplicatedExtension
        if let t = cls as? any NSFileProviderReplicatedExtension.Type {
            made = t.init(domain: domain)
        } else if class_respondsToSelector(cls, NSSelectorFromString("initWithDomain:")) {
            // an Objective-C class that conforms to the header's protocol
            typealias Alloc = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
            typealias Init = @convention(c) (AnyObject, Selector, NSFileProviderDomain) -> Unmanaged<AnyObject>
            let allocSel = NSSelectorFromString("alloc"), initSel = NSSelectorFromString("initWithDomain:")
            let alloc = unsafeBitCast(class_getMethodImplementation(object_getClass(cls), allocSel), to: Alloc.self)
            let initf = unsafeBitCast(class_getMethodImplementation(cls, initSel), to: Init.self)
            let obj = initf(alloc(cls, allocSel).takeUnretainedValue(), initSel, domain).takeRetainedValue()
            made = unsafeBitCast(obj, to: (any NSFileProviderReplicatedExtension).self)
        } else {
            throw _fpError(.applicationExtensionNotFound, "\(name) is not an NSFileProviderReplicatedExtension")
        }
        ext = made
        _FPHost.log("loaded \(record.provider) for domain \(record.identifier)")
        return made
    }
    func invalidate() {
        ext?.invalidate()
        ext = nil
    }
    var request: NSFileProviderRequest { NSFileProviderRequest(system: true, version: NSFileProviderDomainVersion(_value: state.version)) }
    var viewerRequest: NSFileProviderRequest { NSFileProviderRequest(viewer: true, version: NSFileProviderDomainVersion(_value: state.version)) }

    // ---- locking across processes, and the state file ----
    func begin() {
        let p = _FPHost.statePath(record) + ".lock"
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        lockFD = open(p, O_CREAT | O_RDWR, 0o644)
        if lockFD >= 0 { flock(lockFD, LOCK_EX) }
        if let d = FileManager.default.contents(atPath: _FPHost.statePath(record)), let s = try? JSONDecoder().decode(_FPState.self, from: d) { state = s }
    }
    func end() {
        if let d = try? JSONEncoder().encode(state) { FileManager.default.createFile(atPath: _FPHost.statePath(record), contents: d) }
        if lockFD >= 0 { flock(lockFD, LOCK_UN); close(lockFD); lockFD = -1 }
    }
    func locked<T>(_ body: () async throws -> T) async rethrows -> T {
        begin()
        defer { end() }
        return try await body()
    }

    // ---- paths ----
    func fullPath(_ id: String) -> String? { state.fullPath(id, root: root) }
    func entry(atPath path: String) -> _FPEntry? { state.entry(atPath: path, root: root) }
    static func mtime(_ p: String) -> Double { ((try? FileManager.default.attributesOfItem(atPath: p))?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0 }
    static func size(_ p: String) -> Int64 { ((try? FileManager.default.attributesOfItem(atPath: p))?[.size] as? NSNumber)?.int64Value ?? 0 }

    // ---- syncing ----
    /// sends local changes, then takes the extension's (changes since the anchor, or everything)
    func sync(full: Bool = false) async throws {
        try await locked {
            try await pushLocalChanges()
            if !full, state.anchor != nil, try await pullChanges() { return }
            try await pullEverything()
        }
        _FPHost.changed(record)
    }
    func syncChanges() async throws { try await sync(full: false) }
    func syncEverything() async throws { try await sync(full: true) }

    func enumerateAll(_ container: NSFileProviderItemIdentifier) async throws -> [NSFileProviderItem] {
        let e = try loadedExtension().enumerator(for: container, request: request)
        defer { e.invalidate() }
        var page = NSFileProviderPage(Data("NSFileProviderInitialPageSortedByName".utf8))
        var all: [NSFileProviderItem] = []
        for _ in 0..<10_000 {
            let o = _FPEnumerationObserver()
            let next: NSFileProviderPage? = try await withCheckedThrowingContinuation { (c: CheckedContinuation<NSFileProviderPage?, any Error>) in
                o.finish = { c.resume(with: $0) }
                e.enumerateItems(for: o, startingAt: page)
            }
            all += o.items
            guard let n = next else { break }
            page = n
        }
        return all
    }

    func pullEverything() async throws {
        var seen = Set<String>()
        var queue = [_fpRoot]
        var fetched: [NSFileProviderItem] = []
        while let c = queue.popLast() {
            for it in try await enumerateAll(c) {
                if it.isTrashed == true { continue }
                let id = it.itemIdentifier.rawValue
                guard !seen.contains(id) else { continue }
                seen.insert(id)
                fetched.append(it)
                if _fpIsFolder(it) { queue.append(it.itemIdentifier) }
            }
        }
        for it in fetched { try await apply(it) }
        for id in Set(state.entries.keys).subtracting(seen) { removeLocally(id) }
        // the working set's current anchor, for the next change enumeration
        if let ws = try? loadedExtension().enumerator(for: _fpWorkingSet, request: request), ws.responds(to: #selector(NSFileProviderEnumerator.currentSyncAnchor(completionHandler:))) {
            let a: NSFileProviderSyncAnchor? = await withCheckedContinuation { c in ws.currentSyncAnchor?(completionHandler: { c.resume(returning: $0) }) }
            state.anchor = a?.rawValue
            ws.invalidate()
        }
        state.version += 1
        _FPHost.log("\(record.identifier): \(state.entries.count) item(s)")
    }

    /// false when the extension cannot enumerate changes from the anchor (then everything is enumerated)
    func pullChanges() async throws -> Bool {
        guard let anchorData = state.anchor else { return false }
        let ws = try loadedExtension().enumerator(for: _fpWorkingSet, request: request)
        defer { ws.invalidate() }
        guard ws.responds(to: #selector(NSFileProviderEnumerator.enumerateChanges(for:from:))) else { return false }
        var anchor = NSFileProviderSyncAnchor(anchorData)
        for _ in 0..<10_000 {
            let o = _FPChangeObserver()
            let result: Result<(NSFileProviderSyncAnchor, Bool), any Error> = await withCheckedContinuation { c in
                o.finish = { c.resume(returning: $0) }
                ws.enumerateChanges?(for: o, from: anchor)
            }
            switch result {
            case .failure(let e as NSError) where e.domain == "NSFileProviderErrorDomain" && e.code == NSFileProviderError.Code.syncAnchorExpired.rawValue:
                return false
            case .failure(let e): throw e
            case .success(let (next, more)):
                for id in o.deleted { removeLocally(id.rawValue) }
                // parents before children
                let ups = o.updated.filter { $0.isTrashed != true }
                var pending = ups
                for _ in 0..<64 where !pending.isEmpty {
                    var later: [NSFileProviderItem] = []
                    for it in pending {
                        let p = it.parentItemIdentifier.rawValue
                        if p == _fpRoot.rawValue || state.entries[p] != nil || !ups.contains(where: { $0.itemIdentifier.rawValue == p }) {
                            try await apply(it)
                        } else { later.append(it) }
                    }
                    pending = later
                }
                for it in o.updated where it.isTrashed == true { removeLocally(it.itemIdentifier.rawValue) }
                anchor = next
                state.anchor = next.rawValue
                if !more {
                    state.version += 1
                    _FPHost.log("\(record.identifier): \(o.updated.count) change(s), \(o.deleted.count) deletion(s)")
                    return true
                }
            }
        }
        return true
    }

    /// puts an item of the extension in the replica
    func apply(_ it: NSFileProviderItem) async throws {
        let id = it.itemIdentifier.rawValue
        let folder = _fpIsFolder(it)
        let v = it.itemVersion
        let content = v?.contentVersion ?? (it.versionIdentifier ?? nil) ?? Data()
        let metadata = v?.metadataVersion ?? Data()
        let old = state.entries[id]
        let oldPath = old != nil ? fullPath(id) : nil
        let eager = it.contentPolicy == .downloadEagerlyAndKeepDownloaded
        var e = _FPEntry(id: id, parent: it.parentItemIdentifier.rawValue, name: it.filename, folder: folder, content: content, metadata: metadata,
                         size: (it.documentSize ?? nil)?.int64Value ?? 0, mtime: old?.mtime ?? 0, dataless: old?.dataless ?? true, eager: eager)
        state.entries[id] = e
        guard let path = fullPath(id) else { return }
        let fm = FileManager.default
        if let op = oldPath, op != path, fm.fileExists(atPath: op) {          // renamed or moved
            try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try? fm.moveItem(atPath: op, toPath: path)
        }
        if folder {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
            e.dataless = false
        } else if old == nil || old!.content != content || !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            fm.createFile(atPath: path, contents: nil)
            if let h = FileHandle(forWritingAtPath: path) { try? h.truncate(atOffset: UInt64(max(e.size, 0))); try? h.close() }
            e.dataless = true
        }
        e.mtime = Self.mtime(path)
        state.entries[id] = e
        if eager && e.dataless { try await fetch(id, viewer: false) }
    }

    func removeLocally(_ id: String) {
        guard state.entries[id] != nil else { return }
        if let p = fullPath(id) { try? FileManager.default.removeItem(atPath: p) }
        let kids = state.entries.values.filter { $0.parent == id }.map(\.id)
        state.entries[id] = nil
        for k in kids { removeLocally(k) }
    }

    // ---- contents ----
    func fetch(_ id: String, viewer: Bool) async throws {
        guard let path = fullPath(id), let e = state.entries[id] else { throw _fpError(.noSuchItem, "no item \(id)") }
        let ext = try loadedExtension()
        let version = NSFileProviderItemVersion(contentVersion: e.content, metadataVersion: e.metadata)
        let item: NSFileProviderItem? = try await withCheckedThrowingContinuation { (c: CheckedContinuation<NSFileProviderItem?, any Error>) in
            var done = false
            _ = ext.fetchContents(for: NSFileProviderItemIdentifier(id), version: version, request: viewer ? viewerRequest : request) { url, item, error in
                guard !done else { return }
                done = true
                if let error { c.resume(throwing: error); return }
                guard let url else { c.resume(throwing: _fpError(.cannotSynchronize, "fetchContents returned no file")); return }
                // copy before the handler returns: the extension may remove its file afterwards
                let tmp = (path as NSString).deletingLastPathComponent + "/.isim-fetch-\(UUID().uuidString)"
                do {
                    try FileManager.default.copyItem(atPath: url.path, toPath: tmp)
                    _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: path), withItemAt: URL(fileURLWithPath: tmp))
                    c.resume(returning: item)
                } catch {
                    try? FileManager.default.removeItem(atPath: tmp)
                    c.resume(throwing: error)
                }
            }
        }
        var n = state.entries[id] ?? e
        if let v = item?.itemVersion { n.content = v.contentVersion; n.metadata = v.metadataVersion }
        n.dataless = false
        n.size = Self.size(path)
        n.mtime = Self.mtime(path)
        state.entries[id] = n
        _FPHost.log("fetched \(n.name)")
    }
    func materialize(_ paths: [String], viewer: Bool = true) async throws {
        try await locked {
            for p in paths {
                guard let e = entry(atPath: p) else { continue }
                if e.folder {
                    for k in state.entries.values where k.dataless && !k.folder && (fullPath(k.id) ?? "").hasPrefix(p + "/") { try await fetch(k.id, viewer: viewer) }
                } else if e.dataless {
                    try await fetch(e.id, viewer: viewer)
                }
            }
        }
    }
    func evict(_ id: String) async throws {
        try await locked {
            try await pushLocalChanges()
            guard let e = state.entries[id], let path = fullPath(id) else { throw _fpError(.noSuchItem, "no item \(id)") }
            guard !e.folder else { return }
            FileManager.default.createFile(atPath: path, contents: nil)
            if let h = FileHandle(forWritingAtPath: path) { try? h.truncate(atOffset: UInt64(max(e.size, 0))); try? h.close() }
            var n = e
            n.dataless = true
            n.mtime = Self.mtime(path)
            state.entries[id] = n
        }
        _FPHost.changed(record)
    }

    // ---- local changes ----
    func pushLocalChanges() async throws {
        let fm = FileManager.default
        var onDisk: [String] = []                          // paths, parents first
        func walk(_ dir: String) {
            for n in ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).sorted() where !n.hasPrefix(".") {
                let p = (dir as NSString).appendingPathComponent(n)
                onDisk.append(p)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue { walk(p) }
            }
        }
        walk(root)
        var byPath: [String: String] = [:]
        for e in state.entries.values { if let p = fullPath(e.id) { byPath[p] = e.id } }
        let ext = try loadedExtension()

        // deletions: entries whose file is gone (the topmost of a deleted tree only)
        let gone = state.entries.values.filter { e in fullPath(e.id).map { !fm.fileExists(atPath: $0) } ?? false }
        let goneIDs = Set(gone.map(\.id))
        for e in gone where !goneIDs.contains(e.parent) {
            let version = NSFileProviderItemVersion(contentVersion: e.content, metadataVersion: e.metadata)
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in
                var done = false
                _ = ext.deleteItem(identifier: NSFileProviderItemIdentifier(e.id), baseVersion: version, options: e.folder ? [.recursive] : [], request: request) { error in
                    guard !done else { return }
                    done = true
                    if let error { c.resume(throwing: error) } else { c.resume() }
                }
            }
            _FPHost.log("deleted \(e.name)")
            removeLocally(e.id)
        }

        for p in onDisk {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: p, isDirectory: &isDir) else { continue }
            if let id = byPath[p], let e = state.entries[id] {
                // a changed file: new contents
                guard !e.folder, !e.dataless, Self.mtime(p) != e.mtime || Self.size(p) != e.size else { continue }
                let version = NSFileProviderItemVersion(contentVersion: e.content, metadataVersion: e.metadata)
                let item = _FPLocalItem(id: NSFileProviderItemIdentifier(id), parent: NSFileProviderItemIdentifier(e.parent), name: e.name, folder: false,
                                        size: Self.size(p), created: nil, modified: Date(timeIntervalSince1970: Self.mtime(p)), version: version)
                let (newItem, _): (NSFileProviderItem?, Bool) = try await withCheckedThrowingContinuation { c in
                    var done = false
                    _ = ext.modifyItem(item, baseVersion: version, changedFields: [.contents, .contentModificationDate], contents: URL(fileURLWithPath: p),
                                       options: [], request: request) { item, _, fetch, error in
                        guard !done else { return }
                        done = true
                        if let error { c.resume(throwing: error) } else { c.resume(returning: (item, fetch)) }
                    }
                }
                var n = e
                if let v = newItem?.itemVersion { n.content = v.contentVersion; n.metadata = v.metadataVersion }
                n.size = Self.size(p); n.mtime = Self.mtime(p)
                state.entries[id] = n
                _FPHost.log("modified \(e.name)")
                continue
            }
            // a new file or folder
            let parentPath = (p as NSString).deletingLastPathComponent
            let parent = parentPath == root ? _fpRoot.rawValue : byPath[parentPath]
            guard let parent else { continue }
            let folder = isDir.boolValue
            let name = (p as NSString).lastPathComponent
            let attrs = try? fm.attributesOfItem(atPath: p)
            let template = _FPLocalItem(id: NSFileProviderItemIdentifier("isim.new." + UUID().uuidString), parent: NSFileProviderItemIdentifier(parent), name: name,
                                        folder: folder, size: folder ? nil : Self.size(p), created: attrs?[.creationDate] as? Date,
                                        modified: attrs?[.modificationDate] as? Date,
                                        version: NSFileProviderItemVersion(contentVersion: NSFileProviderItemVersion.beforeFirstSyncComponent,
                                                                           metadataVersion: NSFileProviderItemVersion.beforeFirstSyncComponent))
            var fields: NSFileProviderItemFields = [.filename, .parentItemIdentifier, .creationDate, .contentModificationDate]
            if !folder { fields.insert(.contents) }
            let created: NSFileProviderItem = try await withCheckedThrowingContinuation { c in
                var done = false
                _ = ext.createItem(basedOn: template, fields: fields, contents: folder ? nil : URL(fileURLWithPath: p), options: [], request: request) { item, _, _, error in
                    guard !done else { return }
                    done = true
                    if let error { c.resume(throwing: error) }
                    else if let item { c.resume(returning: item) }
                    else { c.resume(throwing: _fpError(.cannotSynchronize, "createItem returned no item")) }
                }
            }
            let id = created.itemIdentifier.rawValue
            let v = created.itemVersion
            var e = _FPEntry(id: id, parent: parent, name: created.filename, folder: folder, content: v?.contentVersion ?? Data(), metadata: v?.metadataVersion ?? Data(),
                             size: folder ? 0 : Self.size(p), mtime: 0, dataless: false, eager: false)
            state.entries[id] = e
            var path = p
            if created.filename != name, let np = fullPath(id) {         // the provider renamed it (a collision)
                try? fm.moveItem(atPath: p, toPath: np)
                path = np
            }
            e.mtime = Self.mtime(path)
            state.entries[id] = e
            byPath[path] = id
            _FPHost.log("created \(created.filename)")
        }
    }
    func pushOnly() async throws {
        try await locked { try await pushLocalChanges() }
        _FPHost.changed(record)
    }

    // ---- lookups ----
    func userVisibleURL(_ id: String) async throws -> URL {
        if id != _fpRoot.rawValue, state.entries[id] == nil { try await sync() }
        guard let p = fullPath(id) else { throw _fpError(.noSuchItem, "no item \(id)", ["NSFileProviderErrorNonExistentItemIdentifier": id]) }
        return URL(fileURLWithPath: p, isDirectory: id == _fpRoot.rawValue || state.entries[id]?.folder == true)
    }
    func identifier(atPath p: String) -> String? {
        if (p as NSString).standardizingPath == root { return _fpRoot.rawValue }
        return entry(atPath: p)?.id
    }
    func items(_ which: (_FPEntry) -> Bool) -> [NSFileProviderItem] {
        state.entries.values.filter(which).map {
            _FPLocalItem(id: NSFileProviderItemIdentifier($0.id), parent: NSFileProviderItemIdentifier($0.parent), name: $0.name, folder: $0.folder, size: $0.size,
                         created: nil, modified: nil, version: NSFileProviderItemVersion(contentVersion: $0.content, metadataVersion: $0.metadata))
        }
    }
    var domainVersion: Int { state.version }

    // ---- custom actions ----
    func perform(_ action: String, on paths: [String]) async throws {
        let ext = try loadedExtension()
        guard let custom = ext as? any NSFileProviderCustomAction ?? (ext.responds(to: NSSelectorFromString("performActionWithIdentifier:onItemsWithIdentifiers:completionHandler:"))
                                                                         ? unsafeBitCast(ext, to: (any NSFileProviderCustomAction).self) : nil) else {
            throw _fpError(.cannotSynchronize, "\(record.provider) does not perform custom actions")
        }
        let ids = paths.compactMap { identifier(atPath: $0) }.map { NSFileProviderItemIdentifier($0) }
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in
            var done = false
            _ = custom.performAction(identifier: NSFileProviderExtensionActionIdentifier(action), onItemsWithIdentifiers: ids) { error in
                guard !done else { return }
                done = true
                if let error { c.resume(throwing: error) } else { c.resume() }
            }
        }
        _FPHost.log("performed \(action) on \(ids.map(\.rawValue).joined(separator: ","))")
    }
}

// MARK: - for the document picker and browser (UIKit) and the command line

func _fpRun(_ body: @escaping @Sendable () async throws -> Void, _ done: @escaping @convention(block) (NSError?) -> Void) {
    let d = unsafeBitCast(done, to: AnyObject.self)
    Task.detached {
        var err: NSError?
        do { try await body() } catch { err = error as NSError; _FPHost.log("\(error.localizedDescription)") }
        let e = err
        DispatchQueue.main.async { unsafeBitCast(d, to: (@convention(block) (NSError?) -> Void).self)(e) }
    }
}

/// the device's visible domains: [{ name, path, domain, provider, appPath }]
@_cdecl("isim_fp_locations")
public func _isimFPLocations() -> NSArray {
    _FPHost.records().filter { !$0.hidden && !$0.disconnected }.map {
        ["name": $0.displayName, "path": _FPHost.replicaPath($0), "domain": $0.identifier, "provider": $0.provider, "appPath": $0.appPath] as NSDictionary
    } as NSArray
}

/// syncs the domain whose replica holds `path` (the picker opening it)
@_cdecl("isim_fp_open")
public func _isimFPOpen(_ path: NSString, _ done: @escaping @convention(block) (NSError?) -> Void) {
    guard let r = _FPHost.record(containing: path as String) else { done(nil); return }
    let x = _FPHost.replica(r)
    _fpRun({ try await x.syncChanges() }, done)
}

/// fetches the contents of placeholders (the files the picker returns)
@_cdecl("isim_fp_materialize")
public func _isimFPMaterialize(_ paths: NSArray, _ done: @escaping @convention(block) (NSError?) -> Void) {
    let ps = (paths as? [String]) ?? []
    guard let r = ps.lazy.compactMap({ _FPHost.record(containing: $0) }).first else { done(nil); return }
    let x = _FPHost.replica(r)
    _fpRun({ try await x.materialize(ps) }, done)
}

/// sends the local changes below `path` to the extension (after the picker exported or moved files there)
@_cdecl("isim_fp_commit")
public func _isimFPCommit(_ path: NSString, _ done: @escaping @convention(block) (NSError?) -> Void) {
    guard let r = _FPHost.record(containing: path as String) else { done(nil); return }
    let x = _FPHost.replica(r)
    _fpRun({ try await x.pushOnly() }, done)
}

/// what the menu of an item in a replica needs (from the state on disk): { identifier, filename, folder, dataless,
/// contentType, size, domain, provider, appPath, extensionPath }
@_cdecl("isim_fp_item_info")
public func _isimFPItemInfo(_ path: NSString) -> NSDictionary? {
    guard let r = _FPHost.record(containing: path as String),
          let d = FileManager.default.contents(atPath: _FPHost.statePath(r)), let st = try? JSONDecoder().decode(_FPState.self, from: d),
          let e = st.entry(atPath: path as String, root: _FPHost.replicaPath(r)) else { return nil }
    let type = e.folder ? UTType.folder : (UTType(filenameExtension: (e.name as NSString).pathExtension) ?? .data)
    return ["identifier": e.id, "filename": e.name, "folder": e.folder, "dataless": e.dataless, "contentType": type.identifier, "size": e.size,
            "domain": r.identifier, "provider": r.provider, "appPath": r.appPath, "extensionPath": r.extensionPath] as NSDictionary
}

/// the domain whose replica holds `path`: { domain, provider, appPath, extensionPath }
@_cdecl("isim_fp_domain_info")
public func _isimFPDomainInfo(_ path: NSString) -> NSDictionary? {
    guard let r = _FPHost.record(containing: path as String) else { return nil }
    return ["domain": r.identifier, "provider": r.provider, "appPath": r.appPath, "extensionPath": r.extensionPath] as NSDictionary
}

/// a custom action of the file provider extension (NSFileProviderCustomAction) on items of a replica
@_cdecl("isim_fp_perform")
public func _isimFPPerform(_ action: NSString, _ paths: NSArray, _ done: @escaping @convention(block) (NSError?) -> Void) {
    let ps = (paths as? [String]) ?? []
    guard let r = ps.lazy.compactMap({ _FPHost.record(containing: $0) }).first else { done(_fpError(.noSuchItem, "not in a file provider domain")); return }
    let x = _FPHost.replica(r)
    _fpRun({ try await x.perform(action as String, on: ps); try await x.syncChanges() }, done)
}
