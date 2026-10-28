// isim BackgroundAssets: managed asset packs (iOS 26, adapted). On iOS the App Store (or Apple's ba-serve tool) hosts
// an app's asset packs; on isim they are in the device data, added with `isim bgassets pack add APP ID DIR [--version N]
// [--policy essential|prefetch|on-demand] [--language L]`: <isim data>/Library/isim/BackgroundAssets/Hosted/<app>/
// (manifest.json and a directory per pack version). Downloading a pack copies it, with status updates, into the
// system's store (…/BackgroundAssets/Local/<app>/<pack ID>), where url(for:), contents(at:) and descriptor(for:) find its
// files. At install the managed downloader extension downloads the essential and prefetch packs it should; checking
// for updates downloads the newer versions of the local packs and removes the packs no longer hosted.
import Foundation
import System
import ExtensionFoundation

@available(iOS 26.0, *)
public enum ManagedBackgroundAssetsError: Error, LocalizedError, Sendable {
    case assetPackNotFound(withID: String)
    case fileNotFound(at: FilePath)
    public var errorDescription: String? {
        switch self {
        case .assetPackNotFound(let id): return "No asset pack with the ID “\(id)” was found."
        case .fileNotFound(let p): return "No file was found at “\(p.string)”."
        }
    }
}

@available(iOS 27.2, *)
public enum SizeCalculationMethod: Int, Sendable { case logical = 0, allocated = 1 }

@available(iOS 26.0, *)
public struct AssetPack: Identifiable, Hashable, Sendable, Encodable, DecodableWithConfiguration {
    public let id: String
    public let version: Int
    public let downloadSize: Int
    public let userInfo: Data?
    @available(iOS 27.0, *) public var language: Locale.Language? { _language.map { Locale.Language(identifier: $0) } }
    let _language: String?
    let policy: String                /* essential, prefetch, on-demand */
    let directory: String             /* its directory in the hosted store */
    init(id: String, version: Int, downloadSize: Int, userInfo: Data?, _language: String?, policy: String, directory: String) {
        self.id = id; self.version = version; self.downloadSize = downloadSize; self.userInfo = userInfo
        self._language = _language; self.policy = policy; self.directory = directory
    }

    public struct Status: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let downloadAvailable = Status(rawValue: 1 << 0)
        public static let downloading = Status(rawValue: 1 << 1)
        public static let downloaded = Status(rawValue: 1 << 2)
        public static let upToDate = Status(rawValue: 1 << 3)
        public static let outOfDate = Status(rawValue: 1 << 4)
        public static let obsolete = Status(rawValue: 1 << 5)
        public static let updateAvailable = Status(rawValue: 1 << 6)
    }
    /// the pack as a download for the downloader extension
    public func download(for contentRequest: BAContentRequest?) -> BADownload {
        _BAAssetPackDownload(pack: self, essential: contentRequest == .install && policy == "essential")
    }

    enum CodingKeys: String, CodingKey { case id, version, downloadSize, userInfo, language, policy, directory }
    public init(from decoder: any Decoder, configuration: AssetPackManifest.DecodingConfiguration) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        downloadSize = try c.decodeIfPresent(Int.self, forKey: .downloadSize) ?? 0
        userInfo = try c.decodeIfPresent(Data.self, forKey: .userInfo)
        _language = try c.decodeIfPresent(String.self, forKey: .language)
        policy = try c.decodeIfPresent(String.self, forKey: .policy) ?? "on-demand"
        directory = try c.decodeIfPresent(String.self, forKey: .directory) ?? "\(id)-v\(version)"
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(version, forKey: .version); try c.encode(downloadSize, forKey: .downloadSize)
        try c.encodeIfPresent(userInfo, forKey: .userInfo); try c.encodeIfPresent(_language, forKey: .language)
        try c.encode(policy, forKey: .policy); try c.encode(directory, forKey: .directory)
    }
}

/// an asset pack the downloader extension downloads (from isim's hosted store)
@available(iOS 26.0, *)
final class _BAAssetPackDownload: BADownload, @unchecked Sendable {
    let pack: AssetPack
    init(pack: AssetPack, essential: Bool) {
        self.pack = pack
        super.init(identifier: pack.id, priority: essential ? .max : .default, essential: essential)
    }
    required init?(coder: NSCoder) { nil }
    override func _clone() -> BADownload { let d = _BAAssetPackDownload(pack: pack, essential: _essential); d._unique = _unique; return d }
}

@available(iOS 26.0, *)
public struct AssetPackManifest: Sendable, Encodable, DecodableWithConfiguration {
    public struct DecodingConfiguration: Sendable {
        let appGroupID: String
        init(appGroupID: String) { self.appGroupID = appGroupID }
    }
    public let assetPacks: Set<AssetPack>
    let _primary: String?
    init(assetPacks: Set<AssetPack>, primary: String?) { self.assetPacks = assetPacks; _primary = primary }
    public init(contentsOf url: URL, appGroupID: String) throws { try self.init(from: Data(contentsOf: url), appGroupID: appGroupID) }
    public init(from data: Data, appGroupID: String) throws {
        let raw = try JSONDecoder().decode(_Raw.self, from: data)
        self.init(assetPacks: Set(raw.assetPacks.map { p in
            AssetPack(id: p.id, version: p.version ?? 1, downloadSize: p.downloadSize ?? 0, userInfo: p.userInfo, _language: p.language,
                      policy: p.policy ?? "on-demand", directory: p.directory ?? "\(p.id)-v\(p.version ?? 1)")
        }), primary: raw.primaryLanguage)
    }
    /// the manifest's JSON (isim's hosted packs: `isim bgassets pack add`)
    struct _Raw: Decodable {
        struct Pack: Decodable { var id: String; var version: Int?; var downloadSize: Int?; var userInfo: Data?; var language, policy, directory: String? }
        var assetPacks: [Pack]
        var primaryLanguage: String?
    }
    enum CodingKeys: String, CodingKey { case assetPacks, primaryLanguage }
    public init(from decoder: any Decoder, configuration: DecodingConfiguration) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var packs = Set<AssetPack>()
        var a = try c.nestedUnkeyedContainer(forKey: .assetPacks)
        while !a.isAtEnd { packs.insert(try a.decode(AssetPack.self, configuration: configuration)) }
        assetPacks = packs
        _primary = try c.decodeIfPresent(String.self, forKey: .primaryLanguage)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(assetPacks.sorted { $0.id < $1.id }, forKey: .assetPacks)
        try c.encodeIfPresent(_primary, forKey: .primaryLanguage)
    }
    /// the downloads of every pack the request covers (install: the essential and prefetch packs; update: all)
    public func allDownloads(for contentRequest: BAContentRequest?) -> Set<BADownload> {
        Set(assetPacks.filter { contentRequest != .install || $0.policy != "on-demand" }.map { $0.download(for: contentRequest) })
    }
    @available(iOS 27.0, *) public func assetPack(withID id: String) -> AssetPack? { assetPacks.first { $0.id == id } }
    @available(iOS 27.0, *) public var localizedAssetPacks: Set<AssetPack> { assetPacks.filter { $0._language != nil } }
    @available(iOS 27.0, *) public func localizedAssetPacks(for language: Locale.Language) -> Set<AssetPack> {
        assetPacks.filter { $0._language.map { Locale.Language(identifier: $0).languageCode == language.languageCode } ?? false }
    }
    @available(iOS 27.0, *) public var primaryLanguage: Locale.Language? { _primary.map { Locale.Language(identifier: $0) } }
    @available(iOS 27.0, *) public var availableLanguages: [Locale.Language] {
        Array(Set(assetPacks.compactMap(\._language))).sorted().map { Locale.Language(identifier: $0) }
    }
    @available(iOS 27.0, *) public var resolvedLanguage: Locale.Language? {
        let available = Set(assetPacks.compactMap(\._language))
        for p in Locale.preferredLanguages {
            let code = Locale.Language(identifier: p).languageCode?.identifier ?? p
            if let hit = available.first(where: { Locale.Language(identifier: $0).languageCode?.identifier == code }) { return Locale.Language(identifier: hit) }
        }
        return primaryLanguage
    }
}

@available(iOS 26.0, *)
public protocol ManagedDownloaderExtension: BADownloaderExtension where Self.Configuration: ManagedDownloaderExtensionConfiguration {
    func shouldDownload(_ assetPack: AssetPack) -> Bool
}
@available(iOS 26.0, *)
extension ManagedDownloaderExtension {
    public func shouldDownload(_ assetPack: AssetPack) -> Bool { true }
    /// the hosted packs the request covers and the extension wants
    public func downloads(for request: BAContentRequest, manifestURL: URL, extensionInfo: BAAppExtensionInfo) -> Set<BADownload> {
        guard let m = AssetPackManager._hosted() else { return [] }
        let local = AssetPackManager._localPacks()
        let wanted = m.assetPacks.filter { p in
            switch request {
            case .install: return p.policy != "on-demand"
            default: return local[p.id].map { $0 < p.version } ?? false      /* update / periodic: newer versions of local packs */
            }
        }.filter { shouldDownload($0) }
        NSLog("isim BackgroundAssets: managed downloads: %@", wanted.map(\.id).sorted().joined(separator: ", "))
        return Set(wanted.map { $0.download(for: request) })
    }
    public func backgroundDownload(_ finishedDownload: BADownload, finishedWithFileURL fileURL: URL) {}
    public func backgroundDownload(_ failedDownload: BADownload, failedWithError error: any Error) {
        NSLog("isim BackgroundAssets: managed download %@ failed: %@", failedDownload.identifier, "\(error)")
    }
}

@available(iOS 26.0, *)
public actor AssetPackManager {
    public static let shared = AssetPackManager()
    public enum DownloadStatusUpdate: @unchecked Sendable {
        case began(AssetPack)
        case downloading(AssetPack, Progress)
        case paused(AssetPack)
        case finished(AssetPack)
        case failed(AssetPack, any Error)
        var id: String {
            switch self { case .began(let p), .downloading(let p, _), .paused(let p), .finished(let p), .failed(let p, _): return p.id }
        }
    }
    public struct _StatusUpdates: AsyncSequence, Sendable {
        public typealias Element = DownloadStatusUpdate
        public typealias Failure = Never
        let id: String?
        public func makeAsyncIterator() -> AsyncStream<DownloadStatusUpdate>.Iterator { AssetPackManager.updates.stream(id).makeAsyncIterator() }
    }
    /// every pack's download status
    public let statusUpdates: some Sendable & AsyncSequence<AssetPackManager.DownloadStatusUpdate, Never> = _StatusUpdates(id: nil)
    public nonisolated func statusUpdates(forAssetPackWithID assetPackID: String) -> some Sendable & AsyncSequence<AssetPackManager.DownloadStatusUpdate, Never> {
        _StatusUpdates(id: assetPackID)
    }
    final class _Updates: @unchecked Sendable {
        var all: [UUID: (String?, AsyncStream<DownloadStatusUpdate>.Continuation)] = [:]
        let lock = NSLock()
        func stream(_ id: String?) -> AsyncStream<DownloadStatusUpdate> {
            let k = UUID()
            let (s, c) = AsyncStream<DownloadStatusUpdate>.makeStream()
            lock.lock(); all[k] = (id, c); lock.unlock()
            c.onTermination = { _ in self.lock.lock(); self.all[k] = nil; self.lock.unlock() }
            return s
        }
        func yield(_ u: DownloadStatusUpdate) {
            lock.lock(); let cs = all.values.filter { $0.0 == nil || $0.0 == u.id }.map(\.1); lock.unlock()
            for c in cs { c.yield(u) }
        }
    }
    static let updates = _Updates()

    // MARK: the stores
    static var app: String {
        let path = Bundle.main.bundlePath
        if let r = path.range(of: "/PlugIns/") {                        /* an extension: its app */
            let app = String(path[..<r.lowerBound])
            if let id = NSDictionary(contentsOfFile: app + "/Info.plist")?["CFBundleIdentifier"] as? String { return id }
        }
        return Bundle.main.bundleIdentifier ?? "app"
    }
    static var root: String {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? ((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/isim/BackgroundAssets")
    }
    static var hostedDir: String { (root as NSString).appendingPathComponent("Hosted/\(app)") }
    static var localRoot: String { (root as NSString).appendingPathComponent("Local/\(app)") }
    static func _localDir(_ id: String) -> URL { URL(fileURLWithPath: (localRoot as NSString).appendingPathComponent(id)) }
    static func _hosted() -> AssetPackManifest? {
        guard let d = FileManager.default.contents(atPath: (hostedDir as NSString).appendingPathComponent("manifest.json")) else { return nil }
        return try? AssetPackManifest(from: d, appGroupID: "")
    }
    struct LocalRecord: Codable { var id: String; var version: Int; var language: String? }
    /// the local packs: id → version
    static func _localPacks() -> [String: Int] { localRecords().mapValues(\.version) }
    static func localRecords() -> [String: LocalRecord] {
        var out: [String: LocalRecord] = [:]
        for id in (try? FileManager.default.contentsOfDirectory(atPath: localRoot)) ?? [] {
            let f = (localRoot as NSString).appendingPathComponent("\(id)/.isim-pack.json")
            if let d = FileManager.default.contents(atPath: f), let r = try? JSONDecoder().decode(LocalRecord.self, from: d) { out[id] = r }
        }
        return out
    }
    var inFlight: [String: Task<Void, any Error>] = [:]

    /// copies the hosted pack into the local store, reporting its progress
    func _download(_ pack: AssetPack) async throws {
        if let t = inFlight[pack.id] { return try await t.value }
        let t = Task<Void, any Error> {
            let src = (AssetPackManager.hostedDir as NSString).appendingPathComponent(pack.directory)
            let fm = FileManager.default
            guard fm.fileExists(atPath: src) else { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: pack.id) }
            AssetPackManager.updates.yield(.began(pack))
            NSLog("isim BackgroundAssets: downloading asset pack %@ v%ld", pack.id, pack.version)
            let files = (fm.enumerator(atPath: src)?.allObjects as? [String] ?? []).filter { var dir: ObjCBool = false; return fm.fileExists(atPath: (src as NSString).appendingPathComponent($0), isDirectory: &dir) && !dir.boolValue }.sorted()
            let sizes = files.map { ((try? fm.attributesOfItem(atPath: (src as NSString).appendingPathComponent($0)))?[.size] as? Int) ?? 0 }
            let progress = Progress(totalUnitCount: Int64(max(1, sizes.reduce(0, +))))
            let tmp = AssetPackManager.localRoot + "/.\(pack.id)-\(UUID().uuidString)"
            try fm.createDirectory(atPath: tmp, withIntermediateDirectories: true)
            for (f, size) in zip(files, sizes) {
                let dst = (tmp as NSString).appendingPathComponent(f)
                try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                try fm.copyItem(atPath: (src as NSString).appendingPathComponent(f), toPath: dst)
                progress.completedUnitCount += Int64(size)
                AssetPackManager.updates.yield(.downloading(pack, progress))
            }
            let rec = LocalRecord(id: pack.id, version: pack.version, language: pack._language)
            try JSONEncoder().encode(rec).write(to: URL(fileURLWithPath: tmp + "/.isim-pack.json"))
            let dst = AssetPackManager._localDir(pack.id).path
            try? fm.removeItem(atPath: dst)
            try fm.moveItem(atPath: tmp, toPath: dst)
            NSLog("isim BackgroundAssets: asset pack %@ v%ld is local (%ld files)", pack.id, pack.version, files.count)
            AssetPackManager.updates.yield(.finished(pack))
        }
        inFlight[pack.id] = t
        defer { inFlight[pack.id] = nil }
        do { try await t.value } catch {
            AssetPackManager.updates.yield(.failed(pack, error))
            throw error
        }
    }
    func hostedPack(_ id: String) throws -> AssetPack {
        guard let p = AssetPackManager._hosted()?.assetPacks.first(where: { $0.id == id }) else { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: id) }
        return p
    }

    // MARK: packs
    @available(iOS, introduced: 26.0, deprecated: 27.0, renamed: "manifest")
    public var allAssetPacks: Set<AssetPack> { get async throws { AssetPackManager._hosted()?.assetPacks ?? [] } }
    @available(iOS, introduced: 26.0, deprecated: 27.0, message: "use manifest.assetPack(withID:)")
    public func assetPack(withID id: String) async throws -> AssetPack { try hostedPack(id) }
    @available(iOS 27.0, *)
    public var manifest: AssetPackManifest { get async throws { AssetPackManager._hosted() ?? AssetPackManifest(assetPacks: [], primary: nil) } }

    @available(iOS, introduced: 26.0, deprecated: 26.4, renamed: "ensureLocalAvailability(of:requireLatestVersion:)")
    public func ensureLocalAvailability(of assetPack: AssetPack) async throws { try await ensure(assetPack, latest: false) }
    func ensure(_ assetPack: AssetPack, latest shouldUpdate: Bool) async throws {
        if let v = AssetPackManager._localPacks()[assetPack.id], !shouldUpdate || v >= assetPack.version { return }
        try await _download(try hostedPack(assetPack.id))
    }
    /// downloads the pack unless it is local (and, requireLatestVersion, the hosted version)
    @available(iOS 26.4, *)
    public func ensureLocalAvailability(of assetPack: AssetPack, requireLatestVersion shouldUpdate: Bool = false) async throws {
        try await ensure(assetPack, latest: shouldUpdate)
    }
    @available(iOS 27.0, *)
    public struct LocalAvailabilityError: Error, LocalizedError, @unchecked Sendable {
        public let successes: Set<AssetPack>
        public let failures: [AssetPack: any Error]
        public var errorDescription: String? { "\(failures.count) asset pack(s) could not be made available locally." }
    }
    @available(iOS 27.0, *)
    public func ensureLocalAvailability(of assetPacks: Set<AssetPack>, requireLatestVersions shouldUpdate: Bool = false) async throws {
        var ok = Set<AssetPack>(), failed: [AssetPack: any Error] = [:]
        for p in assetPacks.sorted(by: { $0.id < $1.id }) {
            do { try await ensure(p, latest: shouldUpdate); ok.insert(p) } catch { failed[p] = error }
        }
        if !failed.isEmpty { throw LocalAvailabilityError(successes: ok, failures: failed) }
    }
    /// downloads the newer versions of the local packs and removes those no longer hosted
    @discardableResult
    public func checkForUpdates() async throws -> (updatingIDs: Set<String>, removedIDs: Set<String>) {
        let hosted = AssetPackManager._hosted()?.assetPacks ?? []
        var updating = Set<String>(), removed = Set<String>()
        for (id, v) in AssetPackManager._localPacks() {
            if let h = hosted.first(where: { $0.id == id }) {
                if h.version > v { updating.insert(id); Task { try? await self._download(h) } }
            } else {
                try? FileManager.default.removeItem(at: AssetPackManager._localDir(id)); removed.insert(id)
            }
        }
        NSLog("isim BackgroundAssets: updates: updating %@, removed %@", updating.sorted().joined(separator: ","), removed.sorted().joined(separator: ","))
        return (updating, removed)
    }
    public func remove(assetPackWithID assetPackID: String) async throws {
        guard AssetPackManager._localPacks()[assetPackID] != nil else { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: assetPackID) }
        try FileManager.default.removeItem(at: AssetPackManager._localDir(assetPackID))
        NSLog("isim BackgroundAssets: removed asset pack %@", assetPackID)
    }

    // MARK: status
    func status(_ id: String, hosted: AssetPack?) -> AssetPack.Status {
        var s: AssetPack.Status = []
        if inFlight[id] != nil { s.insert(.downloading) }
        if let v = AssetPackManager._localPacks()[id] {
            s.insert(.downloaded)
            if let h = hosted {
                if v >= h.version { s.insert(.upToDate) } else { s.formUnion([.outOfDate, .updateAvailable]) }
            } else { s.insert(.obsolete) }
        } else if hosted != nil { s.insert(.downloadAvailable) }
        return s
    }
    @available(iOS, introduced: 26.0, deprecated: 26.4, renamed: "status(relativeTo:)")
    public func status(ofAssetPackWithID assetPackID: String) async throws -> AssetPack.Status {
        let h = AssetPackManager._hosted()?.assetPacks.first { $0.id == assetPackID }
        guard h != nil || AssetPackManager._localPacks()[assetPackID] != nil else { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: assetPackID) }
        return status(assetPackID, hosted: h)
    }
    @available(iOS 26.4, *)
    public func status(relativeTo assetPack: AssetPack) async throws -> AssetPack.Status { status(assetPack.id, hosted: assetPack) }
    @available(iOS 26.4, *)
    public func localStatus(ofAssetPackWithID assetPackID: String) async -> AssetPack.Status {
        status(assetPackID, hosted: AssetPackManager._hosted()?.assetPacks.first { $0.id == assetPackID })
    }
    @available(iOS 26.4, *)
    public nonisolated func assetPackIsAvailableLocally(withID assetPackID: String) -> Bool { AssetPackManager._localPacks()[assetPackID] != nil }
    @available(iOS 27.2, *)
    public nonisolated func localVersion(ofAssetPackWithID assetPackID: String) throws -> Int {
        guard let v = AssetPackManager._localPacks()[assetPackID] else { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: assetPackID) }
        return v
    }
    @available(iOS 27.2, *)
    public func localSize(ofAssetPackWithID assetPackID: String, calculationMethod: SizeCalculationMethod) async throws -> Int64 {
        guard AssetPackManager._localPacks()[assetPackID] != nil else { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: assetPackID) }
        let dir = AssetPackManager._localDir(assetPackID)
        let keys: [URLResourceKey] = [.fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey]
        var total: Int64 = 0
        for case let u as URL in FileManager.default.enumerator(at: dir, includingPropertiesForKeys: keys) ?? FileManager.DirectoryEnumerator() {
            guard u.lastPathComponent != ".isim-pack.json", let v = try? u.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            total += Int64(calculationMethod == .logical ? (v.fileSize ?? 0) : (v.totalFileAllocatedSize ?? v.fileSize ?? 0))
        }
        return total
    }

    // MARK: files
    static func find(_ path: FilePath, in id: String?, language: String? = nil) throws -> URL {
        let rel = path.string.hasPrefix("/") ? String(path.string.dropFirst()) : path.string
        let records = localRecords()
        let ids = id.map { [$0] } ?? records.keys.sorted()
        if let id, records[id] == nil { throw ManagedBackgroundAssetsError.assetPackNotFound(withID: id) }
        for i in ids {
            if let language {
                let have = records[i]?.language.flatMap { Locale.Language(identifier: $0).languageCode?.identifier }
                if have != Locale.Language(identifier: language).languageCode?.identifier { continue }
            }
            let u = _localDir(i).appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        throw ManagedBackgroundAssetsError.fileNotFound(at: path)
    }
    /// a file of the local packs (the first pack that has it)
    public nonisolated func url(for path: FilePath) throws -> URL { try AssetPackManager.find(path, in: nil) }
    public nonisolated func contents(at path: FilePath, searchingInAssetPackWithID assetPackID: String? = nil, options: Data.ReadingOptions = .mappedIfSafe) throws -> Data {
        try Data(contentsOf: AssetPackManager.find(path, in: assetPackID), options: options)
    }
    public nonisolated func descriptor(for path: FilePath, searchingInAssetPackWithID assetPackID: String? = nil) throws -> FileDescriptor {
        try FileDescriptor.open(FilePath(AssetPackManager.find(path, in: assetPackID).path), .readOnly)
    }
    @available(iOS 27.0, *)
    public nonisolated func url(for path: FilePath, asLocalizedFor language: Locale.Language) throws -> URL {
        try AssetPackManager.find(path, in: nil, language: language.minimalIdentifier)
    }
    @available(iOS 27.0, *)
    public nonisolated func contents(at path: FilePath, asLocalizedFor language: Locale.Language, options: Data.ReadingOptions = .mappedIfSafe) throws -> Data {
        try Data(contentsOf: AssetPackManager.find(path, in: nil, language: language.minimalIdentifier), options: options)
    }
    @available(iOS 27.0, *)
    public nonisolated func descriptor(for path: FilePath, asLocalizedFor language: Locale.Language) throws -> FileDescriptor {
        try FileDescriptor.open(FilePath(AssetPackManager.find(path, in: nil, language: language.minimalIdentifier).path), .readOnly)
    }

    // MARK: languages (iOS 27)
    nonisolated(unsafe) static var chosenLanguage: Locale.Language?
    @available(iOS 27.0, *)
    public nonisolated var resolvedLanguage: Locale.Language? {
        get { AssetPackManager.chosenLanguage ?? AssetPackManager._hosted()?.resolvedLanguage }
        set { AssetPackManager.chosenLanguage = newValue }
    }
    @available(iOS 27.0, *)
    public var locallyAvailableLanguages: [Locale.Language] {
        get async { Array(Set(AssetPackManager.localRecords().values.compactMap(\.language))).sorted().map { Locale.Language(identifier: $0) } }
    }
    /// downloads the resolved language's packs and removes the local packs of other languages
    @available(iOS 27.0, *)
    public func reconcilePreferredLanguages() async throws {
        guard let lang = resolvedLanguage?.languageCode?.identifier, let hosted = AssetPackManager._hosted() else { return }
        for (id, r) in AssetPackManager.localRecords() {
            if let l = r.language, Locale.Language(identifier: l).languageCode?.identifier != lang { try? FileManager.default.removeItem(at: AssetPackManager._localDir(id)) }
        }
        for p in hosted.assetPacks where p._language.map({ Locale.Language(identifier: $0).languageCode?.identifier == lang }) ?? false {
            try await _download(p)
        }
        NSLog("isim BackgroundAssets: asset packs reconciled for %@", lang)
    }
}
