// isim BackgroundAssets (adapted): downloads of an app's assets outside the App Store's app download. BADownloadManager
// downloads with URLSession in the app's process (iOS hands them to the system's download daemon): scheduled
// downloads start after a moment, foreground ones at once; the delegate hears begin, progress, pause, authentication
// challenges and the result, and must move the finished file before the call returns, like on iOS. The downloader
// extension (Extension.swift) runs as a helper process the home screen starts when the app is installed and on
// `isim bgassets run APP update|periodic`. Asset packs (iOS 26): AssetPacks.swift.
import Foundation

public let BAErrorDomain: String = "BAErrorDomain"

@objc public enum BAErrorCode: Int, Sendable {
    case downloadInvalid = 0
    case callFromExtensionNotAllowed = 50
    case callFromInactiveProcessNotAllowed = 51
    case callerConnectionNotAccepted = 55
    case callerConnectionInvalid = 56
    case downloadAlreadyScheduled = 100
    case downloadNotScheduled = 101
    case downloadFailedToStart = 102
    case downloadAlreadyFailed = 103
    case downloadEssentialDownloadNotPermitted = 109
    case downloadBackgroundActivityProhibited = 111
    case downloadWouldExceedAllowance = 112
    case downloadDoesNotExist = 113
    case sessionDownloadDisallowedByDomain = 202
    case sessionDownloadDisallowedByAllowance = 203
    case sessionDownloadAllowanceExceeded = 204
    case sessionDownloadNotPermittedBeforeAppLaunch = 206
}
func _baError(_ code: BAErrorCode, _ why: String) -> NSError {
    NSError(domain: BAErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: why])
}

@objc public enum BAContentRequest: Int, Sendable {
    case install = 1, update = 2, periodic = 3
    @available(iOS 27.0, *) case languageChange = 4
}

/// the extension's download allowances (the app's BAEssentialMaxInstallSize / BAMaxInstallSize)
@objc(BAAppExtensionInfo) open class BAAppExtensionInfo: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc(restrictedDownloadSizeRemaining) public var _restricted: NSNumber? { restricted.map { NSNumber(value: $0) } }
    @objc(restrictedEssentialDownloadSizeRemaining) public var _restrictedEssential: NSNumber? { restrictedEssential.map { NSNumber(value: $0) } }
    @nonobjc public var restrictedDownloadSizeRemaining: Int? { restricted }
    @available(iOS 16.4, *) @nonobjc public var restrictedEssentialDownloadSizeRemaining: Int? { restrictedEssential }
    let restricted: Int?, restrictedEssential: Int?
    init(restricted: Int?, essential: Int?) { self.restricted = restricted; restrictedEssential = essential; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        let r = coder.decodeObject(forKey: "restricted") as? NSNumber, e = coder.decodeObject(forKey: "essential") as? NSNumber
        restricted = r.map { Int(truncating: $0) }
        restrictedEssential = e.map { Int(truncating: $0) }
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(restricted.map { NSNumber(value: $0) }, forKey: "restricted")
        coder.encode(restrictedEssential.map { NSNumber(value: $0) }, forKey: "essential")
    }
}

@objc(BADownload) open class BADownload: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    @objc(BADownloadState) public enum State: Int, Sendable { case failed = -1, created = 0, waiting = 1, downloading = 2, finished = 3 }
    public struct Priority: RawRepresentable, Hashable, Comparable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public init(_ rawValue: Int) { self.rawValue = rawValue }
        public static let min = Priority(rawValue: 0)
        public static let `default` = Priority(rawValue: 50)
        public static let max = Priority(rawValue: 100)
        public static func < (a: Priority, b: Priority) -> Bool { a.rawValue < b.rawValue }
    }
    @objc open var identifier: String { _identifier }
    @objc open var uniqueIdentifier: String { _unique }
    open var priority: BADownload.Priority { _priority }
    @objc(priority) public var _objcPriority: Int { _priority.rawValue }
    @available(iOS 16.4, *) @objc open var isEssential: Bool { _essential }
    @objc open var state: BADownload.State { _state }
    var _identifier: String, _unique: String, _priority: Priority, _essential: Bool
    var _state: State = .created
    init(identifier: String, priority: Priority, essential: Bool) {
        _identifier = identifier; _unique = UUID().uuidString; _priority = priority; _essential = essential
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let i = coder.decodeObject(of: NSString.self, forKey: "identifier") as String?,
              let u = coder.decodeObject(of: NSString.self, forKey: "unique") as String? else { return nil }
        _identifier = i; _unique = u
        _priority = Priority(rawValue: coder.decodeInteger(forKey: "priority"))
        _essential = coder.decodeBool(forKey: "essential")
        _state = State(rawValue: coder.decodeInteger(forKey: "state")) ?? .created
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(_identifier as NSString, forKey: "identifier"); coder.encode(_unique as NSString, forKey: "unique")
        coder.encode(_priority.rawValue, forKey: "priority"); coder.encode(_essential, forKey: "essential"); coder.encode(_state.rawValue, forKey: "state")
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    /// the same download, not essential (it may then run after the app launched)
    @available(iOS 16.4, *)
    @objc open func removingEssential() -> Self {
        let d = _clone()
        d._essential = false
        return d as! Self
    }
    func _clone() -> BADownload { let d = BADownload(identifier: _identifier, priority: _priority, essential: _essential); d._unique = _unique; return d }
    open override func isEqual(_ object: Any?) -> Bool { (object as? BADownload)?._unique == _unique }
    open override var hash: Int { _unique.hashValue }
    open override var description: String { "<\(type(of: self)) \(_identifier) \(_state)>" }
}

@objc(BAURLDownload) open class BAURLDownload: BADownload, @unchecked Sendable {
    let request: URLRequest, fileSize: Int, group: String
    @available(iOS 16.4, *)
    public init(identifier: String, request: URLRequest, essential: Bool, fileSize: Int, applicationGroupIdentifier: String, priority: BADownload.Priority) {
        self.request = request; self.fileSize = fileSize; group = applicationGroupIdentifier
        super.init(identifier: identifier, priority: priority, essential: essential)
    }
    @available(iOS 16.4, *)
    public convenience init(identifier: String, request: URLRequest, fileSize: Int, applicationGroupIdentifier: String) {
        self.init(identifier: identifier, request: request, essential: false, fileSize: fileSize, applicationGroupIdentifier: applicationGroupIdentifier, priority: .default)
    }
    @available(iOS, introduced: 16.1, deprecated: 16.4)
    public convenience init(identifier: String, request: URLRequest, applicationGroupIdentifier: String) {
        self.init(identifier: identifier, request: request, essential: false, fileSize: 0, applicationGroupIdentifier: applicationGroupIdentifier, priority: .default)
    }
    @available(iOS, introduced: 16.1, deprecated: 16.4)
    public convenience init(identifier: String, request: URLRequest, applicationGroupIdentifier: String, priority: BADownload.Priority) {
        self.init(identifier: identifier, request: request, essential: false, fileSize: 0, applicationGroupIdentifier: applicationGroupIdentifier, priority: priority)
    }
    @objc(initWithIdentifier:request:essential:fileSize:applicationGroupIdentifier:priority:)
    public convenience init(_objcIdentifier identifier: String, request: URLRequest, essential: Bool, fileSize: Int, applicationGroupIdentifier: String, priority: Int) {
        self.init(identifier: identifier, request: request, essential: essential, fileSize: fileSize, applicationGroupIdentifier: applicationGroupIdentifier, priority: Priority(rawValue: priority))
    }
    public required init?(coder: NSCoder) {
        guard let u = coder.decodeObject(of: NSURL.self, forKey: "url") as URL?,
              let g = coder.decodeObject(of: NSString.self, forKey: "group") as String? else { return nil }
        request = URLRequest(url: u); fileSize = coder.decodeInteger(forKey: "fileSize"); group = g
        super.init(coder: coder)
    }
    open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(request.url as NSURL?, forKey: "url"); coder.encode(fileSize, forKey: "fileSize"); coder.encode(group as NSString, forKey: "group")
    }
    override func _clone() -> BADownload {
        let d = BAURLDownload(identifier: _identifier, request: request, essential: _essential, fileSize: fileSize, applicationGroupIdentifier: group, priority: _priority)
        d._unique = _unique
        return d
    }
}

@objc public protocol BADownloadManagerDelegate: NSObjectProtocol {
    @objc(downloadDidBegin:) optional func downloadDidBegin(_ download: BADownload)
    @objc(downloadDidPause:) optional func downloadDidPause(_ download: BADownload)
    @objc(download:didWriteBytes:totalBytesWritten:totalBytesExpectedToWrite:)
    optional func download(_ download: BADownload, didWriteBytes bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite totalExpectedBytes: Int64)
    @objc(download:didReceiveChallenge:completionHandler:)
    optional func download(_ download: BADownload, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    @objc(download:failedWithError:) optional func download(_ download: BADownload, failedWithError error: any Error)
    @objc(download:finishedWithFileURL:) optional func download(_ download: BADownload, finishedWithFileURL fileURL: URL)
}

/// performs BAURLDownloads with URLSession, reporting to a sink (the manager's delegate, or the extension)
final class _BATransfers: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    struct Sink {
        var began: (BADownload) -> Void = { _ in }
        var progress: (BADownload, Int64, Int64, Int64) -> Void = { _, _, _, _ in }
        var challenge: (BADownload, URLAuthenticationChallenge, @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void = { _, _, k in k(.performDefaultHandling, nil) }
        var finished: (BADownload, URL) -> Void = { _, _ in }
        var failed: (BADownload, any Error) -> Void = { _, _ in }
    }
    var sink: Sink
    let queue = DispatchQueue(label: "isim.BackgroundAssets.transfers")
    lazy var session: URLSession = {
        let q = OperationQueue(); q.maxConcurrentOperationCount = 1
        return URLSession(configuration: .default, delegate: self, delegateQueue: q)
    }()
    var tasks: [Int: BADownload] = [:]
    var running: [String: (BADownload, URLSessionDownloadTask)] = [:]
    let lock = NSLock()
    init(_ sink: Sink) { self.sink = sink; super.init() }

    func start(_ d: BAURLDownload) {
        let t = session.downloadTask(with: d.request)
        lock.lock(); tasks[t.taskIdentifier] = d; running[d.identifier] = (d, t); lock.unlock()
        d._state = .downloading
        queue.async { self.sink.began(d) }
        t.resume()
    }
    func cancel(_ identifier: String) -> Bool {
        lock.lock(); let r = running.removeValue(forKey: identifier); lock.unlock()
        r?.1.cancel()
        return r != nil
    }
    func current() -> [BADownload] { lock.lock(); defer { lock.unlock() }; return running.values.map(\.0) }
    func download(_ task: URLSessionTask) -> BADownload? { lock.lock(); defer { lock.unlock() }; return tasks[task.taskIdentifier] }
    func done(_ task: URLSessionTask) { lock.lock(); if let d = tasks.removeValue(forKey: task.taskIdentifier) { running[d.identifier] = nil }; lock.unlock() }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let d = download(downloadTask) else { return }
        sink.progress(d, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let d = download(downloadTask) else { return }
        if let h = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            d._state = .failed
            done(downloadTask)
            sink.failed(d, _baError(.downloadFailedToStart, "HTTP status \(h.statusCode) for \(downloadTask.originalRequest?.url?.absoluteString ?? "?")"))
            return
        }
        d._state = .finished
        done(downloadTask)
        sink.finished(d, location)              /* the receiver moves the file now: it is removed when this returns */
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error, let d = download(task) else { return }
        d._state = .failed
        done(task)
        sink.failed(d, error)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let d = download(task) else { completionHandler(.performDefaultHandling, nil); return }
        sink.challenge(d, challenge, completionHandler)
    }
}

@objc(BADownloadManager) open class BADownloadManager: NSObject, @unchecked Sendable {
    @objc(sharedManager) open class var shared: BADownloadManager { _shared }
    static let _shared = BADownloadManager()
    @objc open weak var delegate: (any BADownloadManagerDelegate)?
    var scheduled: [String: BAURLDownload] = [:]
    let lock = NSLock()
    lazy var transfers: _BATransfers = {
        var s = _BATransfers.Sink()
        s.began = { [weak self] d in NSLog("isim BackgroundAssets: download %@ began", d.identifier); self?.delegate?.downloadDidBegin?(d) }
        s.progress = { [weak self] d, w, t, e in self?.delegate?.download?(d, didWriteBytes: w, totalBytesWritten: t, totalBytesExpectedToWrite: e) }
        s.challenge = { [weak self] d, c, k in
            if let del = self?.delegate, del.responds(to: #selector(BADownloadManagerDelegate.download(_:didReceive:completionHandler:))) {
                del.download?(d, didReceive: c, completionHandler: k)
            } else { k(.performDefaultHandling, nil) }
        }
        s.finished = { [weak self] d, url in
            NSLog("isim BackgroundAssets: download %@ finished", d.identifier)
            self?.forget(d)
            self?.delegate?.download?(d, finishedWithFileURL: url)
        }
        s.failed = { [weak self] d, e in
            NSLog("isim BackgroundAssets: download %@ failed: %@", d.identifier, "\(e)")
            self?.forget(d)
            self?.delegate?.download?(d, failedWithError: e)
        }
        return _BATransfers(s)
    }()
    func forget(_ d: BADownload) { lock.lock(); scheduled[d.identifier] = nil; lock.unlock() }
    func validate(_ download: BADownload) throws -> BAURLDownload {
        guard let d = download as? BAURLDownload else { throw _baError(.downloadInvalid, "only BAURLDownload downloads can be scheduled") }
        if d.isEssential { throw _baError(.downloadEssentialDownloadNotPermitted, "essential downloads are scheduled by the downloader extension at install") }
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: d.group) != nil else {
            throw _baError(.downloadInvalid, "the app is not in the app group \(d.group)")
        }
        if d.state == .failed { throw _baError(.downloadAlreadyFailed, "\(d.identifier) failed") }
        return d
    }

    /// queues the download: the system starts it when it sees fit (isim: after a moment)
    @objc(scheduleDownload:error:) open func scheduleDownload(_ download: BADownload) throws {
        let d = try validate(download)
        lock.lock()
        if scheduled[d.identifier] != nil { lock.unlock(); throw _baError(.downloadAlreadyScheduled, "\(d.identifier) is already scheduled") }
        scheduled[d.identifier] = d
        lock.unlock()
        d._state = .waiting
        NSLog("isim BackgroundAssets: scheduled %@", d.identifier)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.lock.lock(); let still = self.scheduled[d.identifier] === d && d.state == .waiting; self.lock.unlock()
            if still { self.transfers.start(d) }
        }
    }
    /// starts the download now, in the foreground (a scheduled one is promoted)
    @objc(startForegroundDownload:error:) open func startForegroundDownload(_ download: BADownload) throws {
        let d = try validate(download)
        lock.lock()
        let existing = scheduled[d.identifier]
        if let e = existing, e.state == .downloading { lock.unlock(); return }
        let run = existing ?? d
        scheduled[d.identifier] = run
        lock.unlock()
        NSLog("isim BackgroundAssets: foreground download %@", d.identifier)
        transfers.start(run)
    }
    @objc(cancelDownload:error:) open func cancel(_ download: BADownload) throws {
        lock.lock(); let known = scheduled.removeValue(forKey: download.identifier); lock.unlock()
        let wasRunning = transfers.cancel(download.identifier)
        guard known != nil || wasRunning else { throw _baError(.downloadDoesNotExist, "\(download.identifier) is not scheduled") }
        NSLog("isim BackgroundAssets: cancelled %@", download.identifier)
    }
    /// the downloads scheduled or running
    @available(iOS 16.4, *)
    @objc(fetchCurrentDownloads:) open func fetchCurrentDownloads() throws -> [BADownload] {
        lock.lock(); defer { lock.unlock() }
        return scheduled.values.sorted { $0.identifier < $1.identifier }
    }
    @objc(fetchCurrentDownloadsWithCompletionHandler:)
    open func fetchCurrentDownloads(completionHandler: @escaping @Sendable ([BADownload], (any Error)?) -> Void) {
        let all = (try? fetchCurrentDownloads()) ?? []
        DispatchQueue.global().async { completionHandler(all, nil) }
    }
    public var currentDownloads: [BADownload] { get async throws { try fetchCurrentDownloads() } }

    // MARK: exclusive control: a lock the app and its extension share (a file in the app group)
    static var lockPath: String {
        let groups = (Bundle.main.object(forInfoDictionaryKey: "BAAppGroupID") as? String).map { [$0] } ?? []
        let base = groups.compactMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)?.path }.first ?? NSTemporaryDirectory()
        return (base as NSString).appendingPathComponent(".isim-backgroundassets.lock")
    }
    static func acquire(before date: Date?) -> Int32? {
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return nil }
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            if let date, Date() >= date { close(fd); return nil }
            usleep(20_000)
        }
        return fd
    }
    static func release(_ fd: Int32) { flock(fd, LOCK_UN); close(fd) }

    @available(iOS, introduced: 16.1, deprecated: 27.0)
    @objc(withExclusiveControl:) open func withExclusiveControl(_ performHandler: @escaping (Bool, (any Error)?) -> Void) {
        let h = _UncheckedSendable(performHandler)
        DispatchQueue.global().async {
            guard let fd = BADownloadManager.acquire(before: nil) else { h.value(false, _baError(.callerConnectionInvalid, "cannot open the lock")); return }
            h.value(true, nil)
            BADownloadManager.release(fd)
        }
    }
    @available(iOS, introduced: 16.1, deprecated: 27.0)
    @objc(withExclusiveControlBeforeDate:performHandler:) open func withExclusiveControl(beforeDate date: Date, perform performHandler: @escaping (Bool, (any Error)?) -> Void) {
        let h = _UncheckedSendable(performHandler)
        DispatchQueue.global().async {
            guard let fd = BADownloadManager.acquire(before: date) else { h.value(false, _baError(.callerConnectionInvalid, "the lock was not free before \(date)")); return }
            h.value(true, nil)
            BADownloadManager.release(fd)
        }
    }
    public final func withExclusiveControl<ReturnType>(_ body: @escaping () throws -> sending ReturnType) async throws -> sending ReturnType {
        try await withExclusiveControl(before: .distantFuture, body)
    }
    public final func withExclusiveControl<ReturnType>(before date: Date, _ body: @escaping () throws -> sending ReturnType) async throws -> sending ReturnType {
        let fd: Int32? = await withCheckedContinuation { k in DispatchQueue.global().async { k.resume(returning: BADownloadManager.acquire(before: date == .distantFuture ? nil : date)) } }
        guard let fd else { throw _baError(.callerConnectionInvalid, "the lock was not free before \(date)") }
        defer { BADownloadManager.release(fd) }
        return try body()
    }
}
struct _UncheckedSendable<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }
