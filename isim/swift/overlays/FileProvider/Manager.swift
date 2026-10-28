// isim FileProvider: NSFileProviderManager, the app's (and its extension's) side of a domain. Adapted: the domains
// and replicas are isim's (Host.swift); a manager's calls sync the replica in this process. Stubs: known folders
// (macOS), services, diagnostics and the testing operations (none are listed).
import Foundation

@objc(NSFileProviderManager)
open class NSFileProviderManager: NSObject, @unchecked Sendable {
    let _record: _FPRecord?
    let _provider: String
    init(record: _FPRecord?, provider: String) { _record = record; _provider = provider }

    /// the manager of the app's provider, for its default domain (non-replicated providers on Apple's)
    @objc(defaultManager) open class var `default`: NSFileProviderManager {
        NSFileProviderManager(record: nil, provider: _FPHost.providerExtension()?.id ?? Bundle.main.bundleIdentifier ?? "")
    }
    /// the manager of one of the app's domains (nil if the app has not added it)
    public convenience init?(for domain: NSFileProviderDomain) {
        guard let r = _FPHost.ownRecords().first(where: { $0.identifier == domain.identifier.rawValue }) else { return nil }
        self.init(record: r, provider: r.provider)
    }
    @available(iOS, deprecated, renamed: "init(for:)")
    public convenience init?(forDomain domain: NSFileProviderDomain) { self.init(for: domain) }
    @objc(managerForDomain:) open class func _objc_manager(for domain: NSFileProviderDomain) -> NSFileProviderManager? { NSFileProviderManager(for: domain) }

    /// the extension's bundle identifier
    @objc open var providerIdentifier: String { _provider }
    /// where a non-replicated provider keeps its documents (isim: a folder per domain beside the replicas)
    @objc open var documentStorageURL: URL {
        let p = (_FPHost.root as NSString).appendingPathComponent("Storage/\(_FPHost.safe(_provider))")
        try? FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        return URL(fileURLWithPath: p, isDirectory: true)
    }

    func replica() throws -> _FPReplica {
        guard let r = _record, let cur = _FPHost.records().first(where: { $0.key == r.key }) else {
            throw _fpError(.providerDomainNotFound, "the domain was removed or not added")
        }
        return _FPHost.replica(cur)
    }
    func _run(_ body: @escaping @Sendable (_FPReplica) async throws -> Void, _ done: @escaping @Sendable ((any Error)?) -> Void) {
        do {
            let x = try replica()
            Task.detached { do { try await body(x); done(nil) } catch { done(error) } }
        } catch { done(error) }
    }

    // MARK: domains

    /// registers a domain of the app's file provider extension: it shows in the document picker and browser
    @objc(addDomain:completionHandler:)
    open class func add(_ domain: NSFileProviderDomain, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        guard let x = _FPHost.providerExtension() else {
            completionHandler(_fpError(.providerNotFound, "\(Bundle.main.bundleIdentifier ?? "the app") has no file provider extension (com.apple.fileprovider-nonui)"))
            return
        }
        let r = _FPRecord(app: Bundle.main.bundleIdentifier ?? "", appPath: Bundle.main.bundlePath, provider: x.id, extensionPath: x.path, executable: x.exe,
                          identifier: domain.identifier.rawValue, displayName: domain.displayName, pathRelative: domain.pathRelativeToDocumentStorage,
                          hidden: domain.isHidden, disconnected: false, userEnabled: true)
        _FPHost.update { rs in
            if let i = rs.firstIndex(where: { $0.key == r.key }) { rs[i] = r } else { rs.append(r) }
        }
        try? FileManager.default.createDirectory(atPath: _FPHost.replicaPath(r), withIntermediateDirectories: true)
        _FPHost.log("added domain \(r.identifier) (\(r.displayName)) of \(r.provider)")
        completionHandler(nil)
    }
    open class func add(_ domain: NSFileProviderDomain) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in add(domain) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    @objc(removeDomain:completionHandler:)
    open class func remove(_ domain: NSFileProviderDomain, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        remove(domain, mode: .removeAll) { _, e in completionHandler(e) }
    }
    open class func remove(_ domain: NSFileProviderDomain) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in remove(domain) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    @available(iOS 16.0, *)
    @objc(NSFileProviderDomainRemovalMode)
    public enum DomainRemovalMode: Int, Sendable {
        case removeAll = 0
        case preserveDirtyUserData = 1
        case preserveDownloadedUserData = 2
    }
    /// removes a domain; the preserving modes keep the replica's files (its local changes, or everything downloaded)
    /// in a folder and return it
    @available(iOS 16.0, *)
    @objc(removeDomain:mode:completionHandler:)
    open class func remove(_ domain: NSFileProviderDomain, mode: DomainRemovalMode, completionHandler: @escaping @Sendable (URL?, (any Error)?) -> Void) {
        guard let r = _FPHost.ownRecords().first(where: { $0.identifier == domain.identifier.rawValue }) else {
            completionHandler(nil, _fpError(.providerDomainNotFound, "no domain \(domain.identifier.rawValue)")); return
        }
        Task.detached {
            if let x = _FPHost.forget(r) { await x.invalidate() }
            _FPHost.update { rs in rs.removeAll { $0.key == r.key } }
            let fm = FileManager.default
            var kept: URL?
            if mode != .removeAll, fm.fileExists(atPath: _FPHost.replicaPath(r)) {
                let dst = (_FPHost.root as NSString).appendingPathComponent("Preserved/\(_FPHost.safe(r.provider))/\(_FPHost.safe(r.identifier))-\(Int(Date().timeIntervalSince1970))")
                try? fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                try? fm.moveItem(atPath: _FPHost.replicaPath(r), toPath: dst)
                kept = URL(fileURLWithPath: dst, isDirectory: true)
            }
            try? fm.removeItem(atPath: _FPHost.replicaPath(r))
            try? fm.removeItem(atPath: _FPHost.statePath(r))
            try? fm.removeItem(atPath: _FPHost.statePath(r) + ".lock")
            _FPHost.log("removed domain \(r.identifier)")
            completionHandler(kept, nil)
        }
    }
    @available(iOS 16.0, *)
    open class func remove(_ domain: NSFileProviderDomain, mode: DomainRemovalMode) async throws -> URL? {
        try await withCheckedThrowingContinuation { c in remove(domain, mode: mode) { u, e in if let e { c.resume(throwing: e) } else { c.resume(returning: u) } } }
    }

    @objc(removeAllDomainsWithCompletionHandler:)
    open class func removeAllDomains(completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        let all = _FPHost.ownRecords()
        guard !all.isEmpty else { completionHandler(nil); return }
        let group = DispatchGroup()
        for r in all { group.enter(); remove(_FPHost.domain(r)) { _ in group.leave() } }
        group.notify(queue: .global()) { completionHandler(nil) }
    }
    open class func removeAllDomains() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in removeAllDomains { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    @objc(getDomainsWithCompletionHandler:)
    open class func getDomainsWithCompletionHandler(_ completionHandler: @escaping @Sendable ([NSFileProviderDomain], (any Error)?) -> Void) {
        completionHandler(_FPHost.ownRecords().map(_FPHost.domain), nil)
    }
    open class func domains() async throws -> [NSFileProviderDomain] { _FPHost.ownRecords().map(_FPHost.domain) }

    /// adds a domain whose items start as the files of a directory (they are created in the provider, then importDidFinish)
    @available(iOS 16.0, *)
    @objc(importDomain:fromDirectoryAtURL:completionHandler:)
    open class func `import`(_ domain: NSFileProviderDomain, fromDirectoryAt url: URL, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        add(domain) { e in
            if let e { completionHandler(e); return }
            guard let m = NSFileProviderManager(for: domain) else { completionHandler(_fpError(.providerDomainNotFound, "the domain was not added")); return }
            let fm = FileManager.default
            guard let r = m._record else { completionHandler(nil); return }
            let dst = _FPHost.replicaPath(r)
            for n in (try? fm.contentsOfDirectory(atPath: url.path)) ?? [] where !n.hasPrefix(".") {
                try? fm.copyItem(atPath: (url.path as NSString).appendingPathComponent(n), toPath: (dst as NSString).appendingPathComponent(n))
            }
            m._run({ x in
                try await x.pushOnly()
                let ext = try await x.loadedExtension()
                if ext.responds(to: #selector(NSFileProviderReplicatedExtension.importDidFinish(completionHandler:))) {
                    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in ext.importDidFinish?(completionHandler: { c.resume() }) }
                }
            }, completionHandler)
        }
    }
    @available(iOS 16.0, *)
    open class func `import`(_ domain: NSFileProviderDomain, fromDirectoryAt url: URL) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in `import`(domain, fromDirectoryAt: url) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    /// whether domains can live on a volume (macOS); isim's replicas are on the device's data volume
    public enum EligibilityResult: Sendable {
        case eligible
        case ineligible(NSFileProviderVolumeUnsupportedReason)
    }
    open class func checkDomainsCanBeStoredOnVolume(at url: URL) throws -> EligibilityResult { .eligible }
    @objc(checkDomainsCanBeStoredOnVolumeAtURL:unsupportedReason:error:)
    open class func _objc_checkDomainsCanBeStoredOnVolume(at url: URL, unsupportedReason: UnsafeMutablePointer<UInt>?) throws {
        unsupportedReason?.pointee = 0
    }

    // MARK: user-visible files

    /// the item's file in the replica (syncing first when the item is not there yet)
    @available(iOS 16.0, *)
    @objc(getUserVisibleURLForItemIdentifier:completionHandler:)
    open func getUserVisibleURL(for itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (URL?, (any Error)?) -> Void) {
        do {
            let x = try replica()
            Task.detached { do { completionHandler(try await x.userVisibleURL(itemIdentifier.rawValue), nil) } catch { completionHandler(nil, error) } }
        } catch { completionHandler(nil, error) }
    }
    @available(iOS 16.0, *)
    open func getUserVisibleURL(for itemIdentifier: NSFileProviderItemIdentifier) async throws -> URL {
        try await withCheckedThrowingContinuation { c in getUserVisibleURL(for: itemIdentifier) { u, e in if let u { c.resume(returning: u) } else { c.resume(throwing: e ?? _fpError(.noSuchItem, "no item")) } } }
    }

    @available(iOS 16.0, *)
    @objc(getIdentifierForUserVisibleFileAtURL:completionHandler:)
    open class func getIdentifierForUserVisibleFile(at url: URL, completionHandler: @escaping @Sendable (NSFileProviderItemIdentifier?, NSFileProviderDomainIdentifier?, (any Error)?) -> Void) {
        guard let r = _FPHost.record(containing: url.path) else { completionHandler(nil, nil, _fpError(.noSuchItem, "\(url.path) is not in a file provider domain")); return }
        let x = _FPHost.replica(r)
        Task.detached {
            if let id = await x.identifier(atPath: url.path) { completionHandler(NSFileProviderItemIdentifier(id), NSFileProviderDomainIdentifier(r.identifier), nil) }
            else { completionHandler(nil, nil, _fpError(.noSuchItem, "no item at \(url.path)")) }
        }
    }
    @available(iOS 16.0, *)
    open class func identifierForUserVisibleFile(at url: URL) async throws -> (NSFileProviderItemIdentifier, NSFileProviderDomainIdentifier) {
        try await withCheckedThrowingContinuation { c in
            getIdentifierForUserVisibleFile(at: url) { i, d, e in if let i, let d { c.resume(returning: (i, d)) } else { c.resume(throwing: e ?? _fpError(.noSuchItem, "no item")) } }
        }
    }

    /// writes a placeholder for a non-replicated provider (isim keeps no separate placeholder files)
    @objc(writePlaceholderAtURL:withMetadata:error:)
    open class func writePlaceholder(at placeholderURL: URL, withMetadata metadata: NSFileProviderItem) throws {
        FileManager.default.createFile(atPath: placeholderURL.path, contents: Data(metadata.filename.utf8))
    }
    @objc(placeholderURLForURL:)
    open class func placeholderURL(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
    }

    // MARK: changes

    /// tells the system the items below a container changed: isim syncs the domain's replica now
    @objc(signalEnumeratorForContainerItemIdentifier:completionHandler:)
    open func signalEnumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.syncChanges() }, completion)
    }
    open func signalEnumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in signalEnumerator(for: containerItemIdentifier) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    /// a URL session task that transfers an item (isim does not track it)
    @objc(registerURLSessionTask:forItemWithIdentifier:completionHandler:)
    open func register(_ task: URLSessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping @Sendable ((any Error)?) -> Void) {
        completion(nil)
    }
    open func register(_ task: URLSessionTask, forItemWithIdentifier identifier: NSFileProviderItemIdentifier) async throws {}

    @objc(reconnectWithCompletionHandler:)
    open func reconnect(completionHandler: @escaping @Sendable ((any Error)?) -> Void) { setDisconnected(false); completionHandler(nil) }
    open func reconnect() async throws { setDisconnected(false) }
    public struct DisconnectionOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var temporary: DisconnectionOptions { .init(rawValue: 1 << 0) }
    }
    /// a disconnected domain does not show in the picker until reconnect
    open func disconnect(reason localizedReason: String, options: DisconnectionOptions = [], completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        setDisconnected(true); completionHandler(nil)
    }
    open func disconnect(reason localizedReason: String, options: DisconnectionOptions = []) async throws { setDisconnected(true) }
    @objc(disconnectWithReason:options:completionHandler:)
    func _objc_disconnect(reason: String, options: UInt, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        disconnect(reason: reason, options: DisconnectionOptions(rawValue: options), completionHandler: completionHandler)
    }
    func setDisconnected(_ d: Bool) {
        guard let r = _record else { return }
        _FPHost.update { rs in if let i = rs.firstIndex(where: { $0.key == r.key }) { rs[i].disconnected = d } }
    }

    /// turns a downloaded file back into a placeholder
    @available(iOS 16.0, *)
    @objc(evictItemWithIdentifier:completionHandler:)
    open func evictItem(identifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.evict(itemIdentifier.rawValue) }, completionHandler)
    }
    @available(iOS 16.0, *)
    open func evictItem(identifier itemIdentifier: NSFileProviderItemIdentifier) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in evictItem(identifier: itemIdentifier) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    /// sends the replica's local changes to the extension
    @available(iOS 16.0, *)
    @objc(waitForChangesOnItemsBelowItemWithIdentifier:completionHandler:)
    open func waitForChanges(below itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.pushOnly() }, completionHandler)
    }
    @available(iOS 16.0, *)
    open func waitForChanges(below itemIdentifier: NSFileProviderItemIdentifier) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in waitForChanges(below: itemIdentifier) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    /// local changes sent and the extension's taken
    @available(iOS 16.0, *)
    @objc(waitForStabilizationWithCompletionHandler:)
    open func waitForStabilization(completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.syncChanges() }, completionHandler)
    }
    @available(iOS 16.0, *)
    open func waitForStabilization() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in waitForStabilization { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    /// enumerates everything again
    @available(iOS 16.0, *)
    @objc(reimportItemsBelowItemWithIdentifier:completionHandler:)
    open func reimportItems(below itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.syncEverything() }, completionHandler)
    }
    @available(iOS 16.0, *)
    open func reimportItems(below itemIdentifier: NSFileProviderItemIdentifier) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in reimportItems(below: itemIdentifier) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    /// asks the system to send an item's fields again (isim: the next sync sends the item's local changes)
    @available(iOS 16.0, *)
    open func requestModification(of fields: NSFileProviderItemFields, forItemWithIdentifier itemIdentifier: NSFileProviderItemIdentifier,
                                  options: NSFileProviderModifyItemOptions = [], completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.pushOnly() }, completionHandler)
    }
    @available(iOS 16.0, *)
    open func requestModification(of fields: NSFileProviderItemFields, forItemWithIdentifier itemIdentifier: NSFileProviderItemIdentifier,
                                  options: NSFileProviderModifyItemOptions = []) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in
            requestModification(of: fields, forItemWithIdentifier: itemIdentifier, options: options) { e in if let e { c.resume(throwing: e) } else { c.resume() } }
        }
    }
    @available(iOS 16.0, *)
    @objc(requestModificationOfFields:forItemWithIdentifier:options:completionHandler:)
    func _objc_requestModification(_ fields: UInt, forItemWithIdentifier itemIdentifier: NSFileProviderItemIdentifier, options: UInt,
                                   completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        requestModification(of: NSFileProviderItemFields(rawValue: fields), forItemWithIdentifier: itemIdentifier,
                            options: NSFileProviderModifyItemOptions(rawValue: options), completionHandler: completionHandler)
    }
    /// downloads an item's contents into its replica file
    @available(iOS 16.0, *)
    open func requestDownloadForItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, requestedRange: NSRange? = nil,
                                     completionHandler: @escaping ((any Error)?) -> Void) {
        let done = _FPUnchecked(completionHandler)
        _run({ x in
            let url = try await x.userVisibleURL(itemIdentifier.rawValue)
            try await x.materialize([url.path], viewer: false)
        }, { e in done.value(e) })
    }
    @available(iOS 16.0, *)
    open func requestDownloadForItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, requestedRange: NSRange? = nil) async throws {
        let x = try replica()
        let url = try await x.userVisibleURL(itemIdentifier.rawValue)
        try await x.materialize([url.path], viewer: false)
    }
    @available(iOS 16.0, *)
    @objc(requestDownloadForItemWithIdentifier:requestedRange:completionHandler:)
    func _objc_requestDownload(_ itemIdentifier: NSFileProviderItemIdentifier, requestedRange: NSRange, completionHandler: @escaping ((any Error)?) -> Void) {
        requestDownloadForItem(withIdentifier: itemIdentifier, requestedRange: requestedRange, completionHandler: completionHandler)
    }
    @available(iOS 16.0, *)
    @objc(signalErrorResolved:completionHandler:)
    open func signalErrorResolved(_ error: any Error, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _run({ try await $0.syncChanges() }, completionHandler)
    }
    @available(iOS 16.0, *)
    open func signalErrorResolved(_ error: any Error) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in signalErrorResolved(error) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }

    // MARK: progress and the system's enumerators

    @available(iOS 16.0, *)
    open func globalProgress(for kind: Progress.FileOperationKind) -> Progress {
        let p = Progress(totalUnitCount: 0)
        p.fileOperationKind = kind
        return p
    }
    @available(iOS 16.0, *)
    @objc(globalProgressForKind:) func _objc_globalProgress(_ kind: String) -> Progress { globalProgress(for: Progress.FileOperationKind(rawValue: kind)) }

    /// the replica's downloaded items
    @available(iOS 16.0, *)
    @objc open func enumeratorForMaterializedItems() -> any NSFileProviderEnumerator { _FPLocalEnumerator(manager: self, pending: false) }
    /// the replica's items with local changes not sent yet (isim sends them at once, so it is empty)
    @available(iOS 16.0, *)
    @objc open func enumeratorForPendingItems() -> any NSFileProviderPendingSetEnumerator { _FPLocalEnumerator(manager: self, pending: true) }

    @available(iOS 16.0, *)
    @objc(temporaryDirectoryURLWithError:)
    open func temporaryDirectoryURL() throws -> URL {
        guard let r = _record else { throw _fpError(.providerDomainNotFound, "no domain") }
        return _FPHost.dir("Temp", r)
    }
    @objc(stateDirectoryURLWithError:)
    open func stateDirectoryURL() throws -> URL {
        guard let r = _record else { throw _fpError(.providerDomainNotFound, "no domain") }
        return _FPHost.dir("ExtensionState", r)
    }

    // MARK: stubs

    @available(iOS 16.0, *)
    open func getService(named serviceName: NSFileProviderServiceName, for itemIdentifier: NSFileProviderItemIdentifier,
                         completionHandler: @escaping @Sendable (NSFileProviderService?, (any Error)?) -> Void) {
        completionHandler(nil, nil)
    }
    @available(iOS 16.0, *)
    open func service(named serviceName: NSFileProviderServiceName, for itemIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderService? { nil }
    @available(iOS 16.0, *)
    @objc(getServiceWithName:itemIdentifier:completionHandler:)
    func _objc_getService(_ name: NSFileProviderServiceName, itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping @Sendable (NSFileProviderService?, (any Error)?) -> Void) {
        getService(named: name, for: itemIdentifier, completionHandler: completionHandler)
    }

    @objc(requestDiagnosticCollectionForItemWithIdentifier:errorReason:completionHandler:)
    open func requestDiagnosticCollection(for itemIdentifier: NSFileProviderItemIdentifier, errorReason: any Error, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        _FPHost.log("diagnostics requested for \(itemIdentifier.rawValue): \(errorReason.localizedDescription)")
        completionHandler(nil)
    }
    open func requestDiagnosticCollection(for itemIdentifier: NSFileProviderItemIdentifier, errorReason: any Error) async throws {}

    static var knownFoldersUnsupported: NSError {
        NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [NSLocalizedDescriptionKey: "known folders are a macOS feature"])
    }
    @objc(claimKnownFolders:localizedReason:completionHandler:)
    open func claimKnownFolders(_ knownFolders: NSFileProviderKnownFolderLocations, localizedReason: String, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        completionHandler(Self.knownFoldersUnsupported)
    }
    open func claimKnownFolders(_ knownFolders: NSFileProviderKnownFolderLocations, localizedReason: String) async throws { throw Self.knownFoldersUnsupported }
    open func releaseKnownFolders(_ knownFolders: NSFileProviderKnownFolders, localizedReason: String, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        completionHandler(Self.knownFoldersUnsupported)
    }
    open func releaseKnownFolders(_ knownFolders: NSFileProviderKnownFolders, localizedReason: String) async throws { throw Self.knownFoldersUnsupported }
    @objc(releaseKnownFolders:localizedReason:completionHandler:)
    func _objc_releaseKnownFolders(_ knownFolders: UInt, localizedReason: String, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        releaseKnownFolders(NSFileProviderKnownFolders(rawValue: knownFolders), localizedReason: localizedReason, completionHandler: completionHandler)
    }

    /// the testing operations of a domain in testing mode: isim lists none
    @available(iOS 16.0, *)
    @objc(listAvailableTestingOperationsWithError:)
    open func listAvailableTestingOperations() throws -> [any NSFileProviderTestingOperation] { [] }
    @available(iOS 16.0, *)
    @objc(runTestingOperations:error:)
    open func run(_ operations: [any NSFileProviderTestingOperation]) throws -> [AnyHashable: any Error] { [:] }
}

/// a value that crosses into a task as is (an app's completion handler that is not @Sendable)
struct _FPUnchecked<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

extension _FPHost {
    /// the domains of this app's provider
    static func ownRecords() -> [_FPRecord] {
        let id = providerExtension()?.id
        return records().filter { $0.provider == id || $0.app == Bundle.main.bundleIdentifier }
    }
}

/// the manager's enumerators of the replica's materialized and pending items
@available(iOS 16.0, *)
final class _FPLocalEnumerator: NSObject, NSFileProviderPendingSetEnumerator, @unchecked Sendable {
    let manager: NSFileProviderManager, pending: Bool
    init(manager: NSFileProviderManager, pending: Bool) { self.manager = manager; self.pending = pending }
    var domainVersion: NSFileProviderDomainVersion? { nil }
    var refreshInterval: TimeInterval { 0 }
    var isMaximumSizeReached: Bool { false }
    func invalidate() {}
    func enumerateItems(for observer: any NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let pending = pending
        guard !pending, let x = try? manager.replica() else { observer.finishEnumerating(upTo: nil); return }
        let o = unsafeBitCast(observer, to: AnyObject.self)
        Task.detached {
            let items = await x.items { !$0.dataless && !$0.folder }
            let obs = unsafeBitCast(o, to: (any NSFileProviderEnumerationObserver).self)
            obs.didEnumerate(items)
            obs.finishEnumerating(upTo: nil)
        }
    }
}
