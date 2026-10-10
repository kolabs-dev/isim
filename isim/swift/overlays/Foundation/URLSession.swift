// isim Foundation: URLSession (self-authored, Swift API). HTTP(S) goes through libisim_host (the host's libcurl);
// file: and data: URLs are loaded directly. Each running task has its own transfer thread that blocks on the
// host; delegate callbacks and completion handlers run on the session's delegateQueue (a serial background
// OperationQueue unless one is given), like on iOS. Redirects, cookies and the cache are handled here so the
// delegate sees them. Not implemented: authentication challenges, HTTP pipelining, Progress.
//
// Background sessions (adapted: isim has no transfer daemon): the transfers run in the app, which tells the shell it
// is busy ("transfer") so it is not suspended while they run. While the app is in the background their delegate events
// are held; when the session has nothing left to do, UIKit wakes the app with
// application(_:handleEventsForBackgroundURLSession:completionHandler:), then the held events are delivered and
// urlSessionDidFinishEvents(forBackgroundURLSession:) is called. Completion-handler tasks are refused, as on iOS.
// Unfinished download and file-upload tasks are saved (Library/Caches/isim-nsurlsessiond/IDENTIFIER.plist); creating
// the session with the same identifier starts them again. When the system ends the app (not the user, in the app
// switcher, which discards them), the home screen relaunches it in the background to finish them ("isim-urlsession:"):
// the app hears about a session it does not recreate while launching (UIKit, ISIM_URLSESSION_HANDLED), and the
// session's events follow without a second wake.
import isim_host

// MARK: - configuration
@objc(NSURLSessionConfiguration) open class URLSessionConfiguration: NSObject, @unchecked Sendable {
    open class var `default`: URLSessionConfiguration { URLSessionConfiguration() }
    /// no persistent storage: a private cookie jar and an in-memory cache
    open class var ephemeral: URLSessionConfiguration {
        let c = URLSessionConfiguration()
        c.httpCookieStorage = HTTPCookieStorage(file: nil)
        c.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 0)
        c.urlCredentialStorage = URLCredentialStorage()
        c._ephemeral = true
        return c
    }
    /// a background session: see the top of this file (adapted)
    open class func background(withIdentifier identifier: String) -> URLSessionConfiguration {
        let c = URLSessionConfiguration(); c.identifier = identifier; c.isDiscretionary = false; return c
    }
    public internal(set) var identifier: String?
    public var requestCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    public var timeoutIntervalForRequest: TimeInterval = 60
    public var timeoutIntervalForResource: TimeInterval = 604800
    public var networkServiceType: URLRequest.NetworkServiceType = .default
    public var allowsCellularAccess = true
    public var allowsExpensiveNetworkAccess = true
    public var allowsConstrainedNetworkAccess = true
    public var requiresDNSSECValidation = false
    public var waitsForConnectivity = false
    public var isDiscretionary = false
    public var sharedContainerIdentifier: String?
    public var sessionSendsLaunchEvents = false
    public var shouldUseExtendedBackgroundIdleMode = false
    public var httpShouldUsePipelining = false
    public var httpShouldSetCookies = true
    public var httpCookieAcceptPolicy: HTTPCookie.AcceptPolicy = .onlyFromMainDocumentDomain
    public var httpAdditionalHeaders: [AnyHashable: Any]?
    public var httpMaximumConnectionsPerHost = 6
    public var httpCookieStorage: HTTPCookieStorage? = HTTPCookieStorage.shared
    public var urlCache: URLCache? = URLCache.shared
    public var urlCredentialStorage: URLCredentialStorage? = URLCredentialStorage.shared
    public var protocolClasses: [AnyClass]? = []
    var _ephemeral = false

    func _copy() -> URLSessionConfiguration {
        let c = URLSessionConfiguration()
        c.identifier = identifier; c.requestCachePolicy = requestCachePolicy
        c.timeoutIntervalForRequest = timeoutIntervalForRequest; c.timeoutIntervalForResource = timeoutIntervalForResource
        c.networkServiceType = networkServiceType; c.allowsCellularAccess = allowsCellularAccess
        c.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess; c.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
        c.waitsForConnectivity = waitsForConnectivity; c.isDiscretionary = isDiscretionary
        c.sharedContainerIdentifier = sharedContainerIdentifier; c.sessionSendsLaunchEvents = sessionSendsLaunchEvents
        c.httpShouldUsePipelining = httpShouldUsePipelining; c.httpShouldSetCookies = httpShouldSetCookies
        c.httpCookieAcceptPolicy = httpCookieAcceptPolicy; c.httpAdditionalHeaders = httpAdditionalHeaders
        c.httpMaximumConnectionsPerHost = httpMaximumConnectionsPerHost; c.httpCookieStorage = httpCookieStorage
        c.urlCache = urlCache; c.protocolClasses = protocolClasses; c._ephemeral = _ephemeral; c.urlCredentialStorage = urlCredentialStorage
        return c
    }
}

// MARK: - delegates (Swift protocols with default implementations standing in for Apple's optional methods)
public protocol URLSessionDelegate: NSObjectProtocol {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession)
    /// session-wide challenges (server trust); the async form is used when the app implements that one instead
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
}
extension URLSessionDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {}
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {}
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let box = _URLBox<URLSessionDelegate>(self)
        Task { let r = await box.value.urlSession(session, didReceive: challenge); completionHandler(r.0, r.1) }
    }
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
}
public protocol URLSessionTaskDelegate: URLSessionDelegate {
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask)
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void)
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    /// task challenges (HTTP Basic / Digest, and server trust when the session-level method does not decide)
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?)
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics)
}
extension URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let box = _URLBox<URLSessionTaskDelegate>(self)
        Task { let r = await box.value.urlSession(session, task: task, didReceive: challenge); completionHandler(r.0, r.1) }
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {}
    public func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {}
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {}
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                           completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(request) }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {}
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {}
}
public protocol URLSessionDataDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void)
}
extension URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) { completionHandler(.allow) }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {}
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse,
                           completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void) { completionHandler(proposedResponse) }
}
public protocol URLSessionDownloadDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64)
}
extension URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {}
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {}
}

public let NSURLSessionTransferSizeUnknown: Int64 = -1
public let NSURLSessionDownloadTaskResumeData = "NSURLSessionDownloadTaskResumeData"

// MARK: - session
@objc(NSURLSession) open class URLSession: NSObject, @unchecked Sendable {
    public enum ResponseDisposition: Int, Sendable { case cancel = 0, allow = 1, becomeDownload = 2, becomeStream = 3 }
    public enum DelayedRequestDisposition: Int, Sendable { case continueLoading = 0, useNewRequest = 1, cancel = 2 }

    static let _shared = URLSession(configuration: .default)
    /// no delegate; completion handlers run on a background serial queue
    open class var shared: URLSession { _shared }

    public let configuration: URLSessionConfiguration
    public let delegateQueue: OperationQueue
    open var sessionDescription: String?
    let _lock = NSLock()
    var _delegate: URLSessionDelegate?
    var _tasks: [Int: URLSessionTask] = [:]
    var _nextID = 1
    var _invalidated = false, _finishing = false
    /// background sessions: delegate events held while the app is in the background, and whether the app was woken
    var _held: [() -> Void] = []
    var _waking = false
    var _isBackground: Bool { configuration.identifier != nil }
    /// what isim_tls_probe learnt of each HTTPS server ("host:port"), for the trust and client-certificate challenges
    var _tlsProbes: [String: _TLSProbe] = [:]

    open var delegate: URLSessionDelegate? { _lock.lock(); defer { _lock.unlock() }; return _delegate }

    public convenience init(configuration: URLSessionConfiguration) { self.init(configuration: configuration, delegate: nil, delegateQueue: nil) }
    /// The session keeps a strong reference to its delegate until it is invalidated (as on iOS).
    public init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) {
        self.configuration = configuration._copy()
        _delegate = delegate
        if let queue { delegateQueue = queue } else {
            let q = OperationQueue(); q.maxConcurrentOperationCount = 1; q.name = "NSOperationQueue (URLSession)"
            delegateQueue = q
        }
        super.init()
        if _isBackground { _IsimBackgroundSessions.register(self) }
    }

    // MARK: task factories
    open func dataTask(with request: URLRequest) -> URLSessionDataTask { _add(URLSessionDataTask(self, request)) }
    open func dataTask(with url: URL) -> URLSessionDataTask { dataTask(with: URLRequest(url: url)) }
    open func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        _refuseCompletionHandler()
        let t = URLSessionDataTask(self, request); t._dataCompletion = completionHandler; return _add(t)
    }
    open func dataTask(with url: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }
    open func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask {
        let t = URLSessionUploadTask(self, request); t._uploadBody = bodyData; return _add(t)
    }
    open func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        _refuseCompletionHandler()
        let t = URLSessionUploadTask(self, request); t._uploadBody = bodyData ?? Data(); t._dataCompletion = completionHandler; return _add(t)
    }
    open func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask {
        let t = URLSessionUploadTask(self, request); t._uploadFile = fileURL; return _add(t)
    }
    open func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
        _refuseCompletionHandler()
        let t = URLSessionUploadTask(self, request); t._uploadFile = fileURL; t._dataCompletion = completionHandler; return _add(t)
    }
    open func downloadTask(with request: URLRequest) -> URLSessionDownloadTask { _add(URLSessionDownloadTask(self, request)) }
    open func downloadTask(with url: URL) -> URLSessionDownloadTask { downloadTask(with: URLRequest(url: url)) }
    open func downloadTask(with request: URLRequest, completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        _refuseCompletionHandler()
        let t = URLSessionDownloadTask(self, request); t._downloadCompletion = completionHandler; return _add(t)
    }
    open func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTask { _resumeTask(resumeData) }
    open func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        let t = _resumeTask(resumeData); t._downloadCompletion = completionHandler; return t
    }
    func _resumeTask(_ resumeData: Data) -> URLSessionDownloadTask {
        let plist = (try? PropertyListSerialization.propertyList(from: resumeData, options: [], format: nil)) as? [String: Any]
        let url = (plist?["NSURLSessionDownloadURL"] as? String).flatMap(URL.init(string:)) ?? URL(string: "about:blank")!
        let t = _add(URLSessionDownloadTask(self, URLRequest(url: url)))
        t._resumeData = resumeData
        return t
    }
    open func downloadTask(with url: URL, completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        downloadTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }

    /// iOS raises: background sessions deliver results through their delegate only
    func _refuseCompletionHandler() {
        if _isBackground { fatalError("Completion handler blocks are not supported in background sessions. Use a delegate instead.") }
    }
    func _add<T: URLSessionTask>(_ t: T) -> T {
        _lock.lock()
        t._id = _nextID; _nextID += 1
        let dead = _invalidated || _finishing
        if !dead { _tasks[t._id] = t }
        let d = _delegate as? URLSessionTaskDelegate
        _lock.unlock()
        if dead { t._invalidSession = true }
        if let d { delegateQueue.addOperation { d.urlSession(self, didCreateTask: t) } }
        if _isBackground, !dead { _IsimBackgroundSessions.save(self) }
        return t
    }
    func _remove(_ t: URLSessionTask) {
        _lock.lock()
        _tasks[t._id] = nil
        let invalidateNow = _finishing && _tasks.isEmpty && !_invalidated
        if invalidateNow { _invalidated = true }
        _lock.unlock()
        if invalidateNow { _sendInvalidated() }
        if _isBackground { _IsimBackgroundSessions.save(self); _IsimBackgroundSessions.idleCheck(self) }
    }
    func _sendInvalidated() {
        let d = delegate
        delegateQueue.addOperation {
            d?.urlSession(self, didBecomeInvalidWithError: nil)
            self._lock.lock(); self._delegate = nil; self._lock.unlock()   // releases the delegate, as on iOS
        }
    }

    // MARK: lifecycle
    open func finishTasksAndInvalidate() {
        guard self !== URLSession._shared else { return }
        _lock.lock(); _finishing = true; let empty = _tasks.isEmpty && !_invalidated; if empty { _invalidated = true }; _lock.unlock()
        if empty { _sendInvalidated() }
    }
    open func invalidateAndCancel() {
        guard self !== URLSession._shared else { return }
        _lock.lock(); _finishing = true; let tasks = Array(_tasks.values); let empty = tasks.isEmpty && !_invalidated; if empty { _invalidated = true }; _lock.unlock()
        for t in tasks { t.cancel() }
        if empty { _sendInvalidated() }
    }
    open func reset(completionHandler: @escaping @Sendable () -> Void) {
        configuration.urlCache?.removeAllCachedResponses()
        delegateQueue.addOperation { completionHandler() }
    }
    open func flush(completionHandler: @escaping @Sendable () -> Void) { delegateQueue.addOperation { completionHandler() } }
    open func getAllTasks(completionHandler: @escaping @Sendable ([URLSessionTask]) -> Void) {
        _lock.lock(); let all = _tasks.values.filter { $0.state == .running || $0.state == .suspended }.sorted { $0._id < $1._id }; _lock.unlock()
        delegateQueue.addOperation { completionHandler(all) }
    }
    open func getTasksWithCompletionHandler(_ completionHandler: @escaping @Sendable ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask]) -> Void) {
        getAllTasks { all in
            completionHandler(all.compactMap { $0 as? URLSessionDataTask }.filter { !($0 is URLSessionUploadTask) },
                              all.compactMap { $0 as? URLSessionUploadTask }, all.compactMap { $0 as? URLSessionDownloadTask })
        }
    }
    open var allTasks: [URLSessionTask] { get async { await withCheckedContinuation { c in getAllTasks { c.resume(returning: $0) } } } }
}

// MARK: - tasks
@objc(NSURLSessionTask) open class URLSessionTask: NSObject, @unchecked Sendable {
    public enum State: Int, Sendable { case running = 0, suspended = 1, canceling = 2, completed = 3 }
    public static let defaultPriority: Float = 0.5
    public static let lowPriority: Float = 0.25
    public static let highPriority: Float = 0.75

    let _session: URLSession
    let _lock = NSLock()
    var _id = 0
    var _state: State = .suspended
    var _started = false, _cancelled = false, _invalidSession = false
    var _http: OpaquePointer?
    var _current: URLRequest?
    var _response: URLResponse?
    var _error: Error?
    var _received: Int64 = 0, _sent: Int64 = 0, _expectedReceive: Int64 = NSURLSessionTransferSizeUnknown, _expectedSend: Int64 = 0
    var _taskDelegate: URLSessionTaskDelegate?
    /// internal consumers for async/await, Combine and bytes(): they replace the delegate and completion handler
    var _onResponse: ((URLResponse) -> Void)?
    var _onData: ((Data) -> Void)?
    var _onComplete: ((Error?) -> Void)?

    public let originalRequest: URLRequest?
    public var taskIdentifier: Int { _id }
    public var currentRequest: URLRequest? { _lock.lock(); defer { _lock.unlock() }; return _current }
    public var response: URLResponse? { _lock.lock(); defer { _lock.unlock() }; return _response }
    public var error: Error? { _lock.lock(); defer { _lock.unlock() }; return _error }
    public var state: State { _lock.lock(); defer { _lock.unlock() }; return _state }
    public var countOfBytesReceived: Int64 { _lock.lock(); defer { _lock.unlock() }; return _received }
    public var countOfBytesSent: Int64 { _lock.lock(); defer { _lock.unlock() }; return _sent }
    public var countOfBytesExpectedToReceive: Int64 { _lock.lock(); defer { _lock.unlock() }; return _expectedReceive }
    public var countOfBytesExpectedToSend: Int64 { _lock.lock(); defer { _lock.unlock() }; return _expectedSend }
    public var countOfBytesClientExpectsToSend: Int64 = NSURLSessionTransferSizeUnknown
    public var countOfBytesClientExpectsToReceive: Int64 = NSURLSessionTransferSizeUnknown
    public var taskDescription: String?
    public var priority: Float = URLSessionTask.defaultPriority
    public var earliestBeginDate: Date?
    public var prefersIncrementalDelivery = true
    /// the transfer's progress (totalUnitCount = expected bytes, completedUnitCount = bytes received; uploads: bytes sent)
    public lazy var progress: Progress = { let p = Progress(totalUnitCount: -1); p.cancellationHandler = { [weak self] in self?.cancel() }; return p }()
    var _metrics = URLSessionTaskMetrics()
    var _taskStart = Date()
    var _authFailures: [String: Int] = [:]
    var _trustAccepted = false
    /// iOS 15: a delegate for this task only (asked before the session's)
    public var delegate: URLSessionTaskDelegate? {
        get { _lock.lock(); defer { _lock.unlock() }; return _taskDelegate }
        set { _lock.lock(); _taskDelegate = newValue; _lock.unlock() }
    }

    init(_ session: URLSession, _ request: URLRequest?) {
        _session = session; originalRequest = request; _current = request
        super.init()
    }

    open func resume() {
        _lock.lock()
        guard _state == .suspended else { _lock.unlock(); return }
        _state = .running
        let start = !_started; _started = true
        _lock.unlock()
        guard start else { return }
        if _invalidSession {     // a task created after invalidation fails right away
            Thread.detachNewThread { self._finish(URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "Task created in a session that has been invalidated"])) }
            return
        }
        _taskStart = Date()
        let delay = earliestBeginDate.map { max(0, $0.timeIntervalSinceNow) } ?? 0
        Thread.detachNewThread {
            if delay > 0 { Thread.sleep(forTimeInterval: delay) }
            self._main()
        }
    }
    /// isim: suspending a transfer that has started does not pause it
    open func suspend() {
        _lock.lock(); if _state == .running && !_started { _state = .suspended }; _lock.unlock()
    }
    open func cancel() {
        _lock.lock()
        guard _state == .running || _state == .suspended, !_cancelled else { _lock.unlock(); return }
        _cancelled = true; _state = .canceling
        let h = _http, started = _started
        _started = true
        _lock.unlock()
        if let h { isim_http_cancel(h) }
        _cancelHook()
        if !started { Thread.detachNewThread { self._finish(URLError._make(NSURLErrorCancelled, url: self.originalRequest?.url)) } }
    }
    func _cancelHook() {}
    var _isCancelled: Bool { _lock.lock(); defer { _lock.unlock() }; return _cancelled }

    /// the task's thread: subclasses run their transfer
    func _main() {}

    // MARK: delivery helpers
    var _sessionTaskDelegate: URLSessionTaskDelegate? { delegate ?? (_session.delegate as? URLSessionTaskDelegate) }
    /// runs `body` on the delegate queue and waits for it (keeps callbacks ordered and applies back-pressure)
    func _onQueue(_ body: @escaping () -> Void) {
        if _session._isBackground && _IsimBackgroundSessions.appInBackground {      // held until the app is woken
            _session._lock.lock(); _session._held.append(body); _session._lock.unlock()
            return
        }
        if OperationQueue.current === _session.delegateQueue { body(); return }
        let sem = DispatchSemaphore(value: 0)
        _session.delegateQueue.addOperation { body(); sem.signal() }
        sem.wait()
    }
    /// completes the task: state, then the delegate's didCompleteWithError (unless a completion handler or an
    /// internal consumer handles the result), then removal from the session
    func _finish(_ error: Error?) {
        _lock.lock()
        if _state == .completed { _lock.unlock(); return }
        let err: Error? = _cancelled ? URLError._make(NSURLErrorCancelled, url: originalRequest?.url) : error
        _error = err; _state = .completed; _http = nil
        _lock.unlock()
        _metrics.taskInterval = DateInterval(start: _taskStart, end: max(_taskStart, Date()))
        if !_metrics.transactionMetrics.isEmpty, let d = _sessionTaskDelegate {
            let m = _metrics
            _onQueue { d.urlSession(self._session, task: self, didFinishCollecting: m) }
        }
        _deliverCompletion(err)
        _session._remove(self)
    }
    /// the body of data/upload tasks that report it at the end (completion handler, async, Combine)
    var _result: Data?
    func _deliverCompletion(_ error: Error?) {
        if let c = _onComplete { c(error); return }
        if let d = _sessionTaskDelegate { _onQueue { d.urlSession(self._session, task: self, didCompleteWithError: error) } }
    }

    // MARK: transfer (shared by data, upload and download tasks)
    /// Loads `request` following redirects; calls `sink` with the final response, then each chunk of the body.
    /// Returns nil on success or the error. `body` overrides the request's httpBody (upload tasks).
    func _load(body: Data?, response onResponse: (URLResponse) -> Bool, data onData: (Data) -> Void) -> (Error?, cacheable: (HTTPURLResponse, URLRequest)?) {
        let config = _session.configuration
        guard var req = originalRequest else { return (URLError(.badURL), nil) }
        if req.cachePolicy == .useProtocolCachePolicy { req.cachePolicy = config.requestCachePolicy }
        if req.timeoutInterval == 60 && config.timeoutIntervalForRequest != 60 { req.timeoutInterval = config.timeoutIntervalForRequest }
        var redirects = 0
        var authHeader: (String, String)? = nil
        var body = body ?? req.httpBody
        while true {
            if _isCancelled { return (URLError._make(NSURLErrorCancelled, url: req.url), nil) }
            _lock.lock(); _current = req; _lock.unlock()
            guard let url = req.url, let scheme = url.scheme?.lowercased() else { return (URLError._make(NSURLErrorBadURL, url: req.url), nil) }
            if scheme == "file" || scheme == "data" {
                guard let (resp, data) = URLSessionTask._loadLocal(url) else { return (URLError._make(scheme == "file" ? NSURLErrorFileDoesNotExist : NSURLErrorBadURL, url: url), nil) }
                _setResponse(resp)
                guard onResponse(resp) else { return (URLError._make(NSURLErrorCancelled, url: url), nil) }
                if !data.isEmpty { _addReceived(Int64(data.count)); onData(data) }
                return (nil, nil)
            }
            guard scheme == "http" || scheme == "https" else { return (URLError._make(NSURLErrorUnsupportedURL, url: url), nil) }
            let method = req.httpMethod ?? "GET"

            // cache lookup
            var cached: CachedURLResponse? = nil
            if method == "GET", let cache = config.urlCache,
               req.cachePolicy != .reloadIgnoringLocalCacheData, req.cachePolicy != .reloadIgnoringLocalAndRemoteCacheData {
                cached = cache.cachedResponse(for: req)
                let useCached: Bool
                switch req.cachePolicy {
                case .returnCacheDataDontLoad:
                    guard cached != nil else { return (URLError._make(NSURLErrorResourceUnavailable, url: url), nil) }
                    useCached = true
                case .returnCacheDataElseLoad: useCached = cached != nil
                case .reloadRevalidatingCacheData: useCached = false
                default: useCached = cached.map { URLSessionTask._isFresh($0) } ?? false
                }
                if useCached, let c = cached { return _deliverCached(c, onResponse, onData) }
            }

            // headers: session additions < request headers; cookies; conditional request for a stale cache entry
            var headers: [(String, String)] = []
            func set(_ k: String, _ v: String) {
                if let i = headers.firstIndex(where: { $0.0.caseInsensitiveCompare(k) == .orderedSame }) { headers[i].1 = v } else { headers.append((k, v)) }
            }
            for (k, v) in config.httpAdditionalHeaders ?? [:] { set("\(k.base)", "\(v)") }
            for (k, v) in req._headers { set(k, v) }
            if !headers.contains(where: { $0.0.lowercased() == "user-agent" }) { set("User-Agent", URLSessionTask._userAgent) }
            if !headers.contains(where: { $0.0.lowercased() == "accept-language" }) { set("Accept-Language", URLSessionTask._acceptLanguage) }
            if config.httpShouldSetCookies && req.httpShouldHandleCookies, let jar = config.httpCookieStorage,
               !headers.contains(where: { $0.0.lowercased() == "cookie" }), let cookies = jar.cookies(for: url), !cookies.isEmpty {
                set("Cookie", cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "))
            }
            if let c = cached as CachedURLResponse?, let h = c.response as? HTTPURLResponse {
                if let etag = h.value(forHTTPHeaderField: "ETag"), req.value(forHTTPHeaderField: "If-None-Match") == nil { set("If-None-Match", etag) }
                if let lm = h.value(forHTTPHeaderField: "Last-Modified"), req.value(forHTTPHeaderField: "If-Modified-Since") == nil { set("If-Modified-Since", lm) }
            }
            if req.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData { set("Cache-Control", "no-cache"); set("Pragma", "no-cache") }
            for (k, v) in _extraHeaders { set(k, v) }
            if let a = authHeader { set(a.0, a.1) }
            // HTTPS: offer the delegate a server-trust challenge first (iOS asks before using the connection), with the
            // server's certificates from a handshake of our own; libcurl's connection is then pinned to that server key.
            // A server that asks for a client certificate gets a client-certificate challenge too.
            var curlFlags: Int32 = 1
            var pinnedKey: String? = nil, clientPEM: [UInt8]? = nil, certificateAsked = false
            if scheme == "https", _session.delegate != nil {
                let host = url.host ?? "", port = url.port ?? 443
                let probe = _session._probe(host: host, port: port, timeout: req.timeoutInterval)
                pinnedKey = probe?.pin
                if !_trustAccepted {
                    let space = URLProtectionSpace(host: host, port: port, protocol: "https", realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust)
                    space._serverTrust = SecTrust(host: host, chain: probe?.chain ?? [])
                    let ch = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: nil, previousFailureCount: 0, failureResponse: nil, error: nil, sender: nil)
                    switch _askChallenge(ch, sessionWide: true) {
                    case (.cancelAuthenticationChallenge, _): return (URLError._make(NSURLErrorCancelled, url: url), nil)
                    case (.useCredential, let c?) where c._trust != nil: _trustAccepted = true
                    default: break
                    }
                }
                if probe?.clientCertificateRequested == true {
                    certificateAsked = true
                    let space = URLProtectionSpace(host: host, port: port, protocol: "https", realm: nil, authenticationMethod: NSURLAuthenticationMethodClientCertificate)
                    space._distinguishedNames = probe?.distinguishedNames ?? []
                    let stored = config.urlCredentialStorage?.defaultCredential(for: space)
                    let ch = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: stored, previousFailureCount: 0, failureResponse: nil, error: nil, sender: nil)
                    switch _askChallenge(ch, sessionWide: true) {
                    case (.cancelAuthenticationChallenge, _): return (URLError._make(NSURLErrorCancelled, url: url), nil)
                    case (.useCredential, let c?) where c._clientPEM != nil:
                        clientPEM = c._clientPEM
                        if c.persistence != .none { config.urlCredentialStorage?.set(c, for: space) }
                    case (.performDefaultHandling, _): clientPEM = stored?._clientPEM
                    default: break
                    }
                }
            }
            if _trustAccepted { curlFlags |= 2 }
            let headerText = headers.map { "\($0.0): \($0.1)" }.joined(separator: "\n")

            let sendBody = method == "GET" || method == "HEAD" ? (body?.isEmpty == false ? body : nil) : body
            var urlString = url.absoluteString
            if let h = urlString.firstIndex(of: "#") { urlString = String(urlString[..<h]) }
            let pem = clientPEM ?? []
            let h: OpaquePointer? = pem.withUnsafeBytes { cp in
                let cpem = clientPEM == nil ? nil : cp.baseAddress
                return sendBody.map { b in
                    b.withUnsafeBytes { p in isim_http_start_tls(method, urlString, headerText, p.baseAddress ?? UnsafeRawPointer(bitPattern: 1), b.count,
                                                                 req.timeoutInterval, config.timeoutIntervalForResource, curlFlags, pinnedKey, cpem, pem.count) }
                } ?? isim_http_start_tls(method, urlString, headerText, nil, 0, req.timeoutInterval, config.timeoutIntervalForResource, curlFlags,
                                         pinnedKey, cpem, pem.count)
            }
            let tm = URLSessionTaskTransactionMetrics(request: req)
            tm.fetchStartDate = Date(); tm.resourceFetchType = .networkLoad
            _metrics.transactionMetrics.append(tm)
            guard let h else {
                return (URLError._make(NSURLErrorNotConnectedToInternet, url: url, detail: "isim needs the host's libcurl (libcurl.so.4) for networking"), nil)
            }
            _lock.lock()
            _http = h
            let cancelledNow = _cancelled
            _expectedSend = Int64(sendBody?.count ?? 0)
            _lock.unlock()
            if cancelledNow { isim_http_cancel(h) }
            defer { _lock.lock(); _http = nil; _lock.unlock(); isim_http_close(h) }

            var status = 0, cURL: UnsafeMutablePointer<CChar>? = nil, cHeaders: UnsafeMutablePointer<CChar>? = nil
            let rc = isim_http_response(h, &status, &cURL, &cHeaders)
            if Int(rc) == NSURLErrorServerCertificateUntrusted, pinnedKey != nil {   /* the server's key changed: probe it again next time */
                _session._lock.lock(); _session._tlsProbes["\((url.host ?? "").lowercased()):\(url.port ?? 443)"] = nil; _session._lock.unlock()
            }
            // the server asked for a client certificate and got none: its refusal (a TLS alert, or just a closed
            // connection, depending on the TLS versions) is clientCertificateRequired, as on iOS
            if certificateAsked && clientPEM == nil && (rc == -1005 || rc == -1200) {
                _fillMetrics(tm, h, response: nil, bodyBytes: 0)
                return (URLError._make(NSURLErrorClientCertificateRequired, url: url, detail: String(cString: isim_http_error_message(h))), nil)
            }
            if rc != 0 { _fillMetrics(tm, h, response: nil, bodyBytes: 0); return (URLError._make(Int(rc), url: url, detail: String(cString: isim_http_error_message(h))), nil) }
            let finalURL = cURL.map { URL(string: String(cString: $0)) ?? url } ?? url
            let (version, fields) = URLSessionTask._parseHeaders(cHeaders.map { String(cString: $0) } ?? "")
            free(cURL); free(cHeaders)
            let resp = HTTPURLResponse(_url: finalURL, statusCode: status, httpVersion: version, headers: fields)

            if let n = sendBody?.count, n > 0 {
                _lock.lock(); _sent = Int64(n); _lock.unlock()
                if _onComplete == nil, let d = _sessionTaskDelegate {
                    _onQueue { d.urlSession(self._session, task: self, didSendBodyData: Int64(n), totalBytesSent: Int64(n), totalBytesExpectedToSend: Int64(n)) }
                }
            }
            // cookies
            if config.httpShouldSetCookies && req.httpShouldHandleCookies, let jar = config.httpCookieStorage, config.httpCookieAcceptPolicy != .never {
                let main = (req.mainDocumentURL ?? finalURL).host?.lowercased() ?? ""
                for c in fields.filter({ $0.0.caseInsensitiveCompare("Set-Cookie") == .orderedSame }).compactMap({ HTTPCookie._parse($0.1, url: finalURL) }) {
                    let d = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
                    if config.httpCookieAcceptPolicy == .onlyFromMainDocumentDomain && !(main == d || main.hasSuffix("." + d)) { continue }
                    jar.setCookie(c)
                }
            }
            // redirects
            if [301, 302, 303, 307, 308].contains(status), let loc = resp.value(forHTTPHeaderField: "Location"),
               let next = URL(string: loc, relativeTo: finalURL) ?? URL(string: loc, encodingInvalidCharacters: true) {
                redirects += 1
                _metrics.redirectCount = redirects
                _fillMetrics(tm, h, response: resp, bodyBytes: 0)
                authHeader = nil
                if redirects > 16 { return (URLError._make(NSURLErrorHTTPTooManyRedirects, url: url), nil) }
                var newReq = req
                newReq.url = next
                if status == 303 || ((status == 301 || status == 302) && method == "POST") {
                    newReq.httpMethod = "GET"; newReq.httpBody = nil; body = nil
                    newReq.setValue(nil, forHTTPHeaderField: "Content-Type"); newReq.setValue(nil, forHTTPHeaderField: "Content-Length")
                }
                let proposed = newReq
                var decided: URLRequest? = proposed
                if let d = _sessionTaskDelegate {
                    let sem = DispatchSemaphore(value: 0)
                    let box = _URLBox<URLRequest?>(nil)
                    _session.delegateQueue.addOperation {
                        d.urlSession(self._session, task: self, willPerformHTTPRedirection: resp, newRequest: proposed) { r in box.value = r; sem.signal() }
                    }
                    sem.wait()
                    decided = box.value
                }
                if let r = decided { req = r; continue }
                // nil: the redirect response itself is the result
            }
            // HTTP authentication (Basic / Digest): ask the delegate, or use the credential storage's default
            if status == 401 || status == 407, let hdr = resp.value(forHTTPHeaderField: status == 401 ? "WWW-Authenticate" : "Proxy-Authenticate"),
               let parsed = _URLAuthChallengeHeader.parse(hdr), let am = parsed.method {
                _fillMetrics(tm, h, response: resp, bodyBytes: 0)
                let space = URLProtectionSpace(host: url.host ?? "", port: url.port ?? (scheme == "https" ? 443 : 80), protocol: scheme,
                                               realm: parsed.params["realm"], authenticationMethod: am)
                let failures = _authFailures[space._key] ?? 0
                _authFailures[space._key] = failures + 1
                let stored = config.urlCredentialStorage?.defaultCredential(for: space)
                let ch = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: stored, previousFailureCount: failures,
                                                    failureResponse: resp, error: nil, sender: nil)
                var (disp, cred) = _askChallenge(ch, sessionWide: false)
                if disp == .performDefaultHandling || disp == .rejectProtectionSpace { cred = failures == 0 ? stored : nil; disp = cred == nil ? .rejectProtectionSpace : .useCredential }
                if disp == .cancelAuthenticationChallenge { return (URLError._make(NSURLErrorCancelled, url: url), nil) }
                if disp == .useCredential, let c = cred, let value = parsed.authorization(c, method: method, url: url, nc: failures + 1) {
                    if c.persistence == .forSession || c.persistence == .permanent { config.urlCredentialStorage?.set(c, for: space) }
                    authHeader = (status == 401 ? "Authorization" : "Proxy-Authorization", value)
                    continue
                }
                // no credential: the 401/407 response is the result
            }
            if status == 304, let c = cached {
                return _deliverCached(c, onResponse, onData)
            }

            _setResponse(resp)
            guard onResponse(resp) else { return (URLError._make(NSURLErrorCancelled, url: url), nil) }
            var buf = [UInt8](repeating: 0, count: 65536)
            var total = 0
            while true {
                let n = buf.withUnsafeMutableBytes { isim_http_read(h, $0.baseAddress!, 65536) }
                if n == 0 { break }
                if n < 0 { return (URLError._make(n, url: url, detail: String(cString: isim_http_error_message(h))), nil) }
                total += n
                _addReceived(Int64(n))
                onData(Data(buf[0..<n]))
            }
            _fillMetrics(tm, h, response: resp, bodyBytes: Int64(total))
            let cacheable = method == "GET" && [200, 203, 300, 301, 410].contains(status) && config.urlCache != nil &&
                req.cachePolicy != .reloadIgnoringLocalAndRemoteCacheData &&
                !_urlContains(resp.value(forHTTPHeaderField: "Cache-Control")?.lowercased() ?? "", "no-store")
            return (nil, cacheable ? (resp, req) : nil)
        }
    }
    /// asks the task delegate (or for session-wide challenges the session delegate first) and waits for the answer
    func _askChallenge(_ ch: URLAuthenticationChallenge, sessionWide: Bool) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let sem = DispatchSemaphore(value: 0)
        let box = _URLBox<(URLSession.AuthChallengeDisposition, URLCredential?)>((.performDefaultHandling, nil))
        nonisolated(unsafe) let taskDelegate = _sessionTaskDelegate     /* called on the session's delegate queue */
        nonisolated(unsafe) let sessionDelegate = _session.delegate
        @Sendable func askTask() {
            guard let td = taskDelegate else { sem.signal(); return }
            nonisolated(unsafe) let d = td
            _session.delegateQueue.addOperation { d.urlSession(self._session, task: self, didReceive: ch) { r, c in box.value = (r, c); sem.signal() } }
        }
        if sessionWide, let sessionDelegate {
            nonisolated(unsafe) let sd = sessionDelegate
            _session.delegateQueue.addOperation {
                sd.urlSession(self._session, didReceive: ch) { r, c in
                    let defers = taskDelegate !== sd || (sd as? _ObjCURLSessionDelegate)?._defersSessionChallenges == true
                    if r == .performDefaultHandling && taskDelegate != nil && defers { askTask() } else { box.value = (r, c); sem.signal() }
                }
            }
        } else { askTask() }
        sem.wait()
        return box.value
    }
    func _fillMetrics(_ tm: URLSessionTaskTransactionMetrics, _ h: OpaquePointer, response: URLResponse?, bodyBytes: Int64) {
        var t = [Double](repeating: -1, count: 7), ints = [Int](repeating: 0, count: 4)
        var remote = [CChar](repeating: 0, count: 64), local = [CChar](repeating: 0, count: 64)
        isim_http_metrics(h, &t, &ints, &remote, 64, &local, 64)
        let start = tm.fetchStartDate ?? Date()
        func at(_ i: Int) -> Date? { t[i] >= 0 ? start.addingTimeInterval(t[i]) : nil }
        tm.response = response
        tm.domainLookupStartDate = t[1] >= 0 ? start : nil; tm.domainLookupEndDate = at(1)
        tm.connectStartDate = at(1); tm.connectEndDate = at(3).flatMap { t[3] > 0 ? $0 : nil } ?? at(2)
        if t[3] > 0 { tm.secureConnectionStartDate = at(2); tm.secureConnectionEndDate = at(3) }
        tm.requestStartDate = at(4); tm.requestEndDate = at(4)
        tm.responseStartDate = at(5); tm.responseEndDate = t[0] >= 0 ? at(0) : Date()
        tm.isReusedConnection = ints[1] == 0 && t[0] >= 0
        if tm.isReusedConnection { tm.domainLookupStartDate = nil; tm.domainLookupEndDate = nil; tm.connectStartDate = nil; tm.connectEndDate = nil }
        tm.networkProtocolName = ints[0] == 3 ? "h2" : ints[0] == 30 ? "h3" : ints[0] == 1 ? "http/1.0" : "http/1.1"
        tm.remoteAddress = remote[0] != 0 ? String(cString: remote) : nil; tm.localAddress = local[0] != 0 ? String(cString: local) : nil
        tm.remotePort = ints[2] > 0 ? ints[2] : nil; tm.localPort = ints[3] > 0 ? ints[3] : nil
        tm.countOfResponseBodyBytesReceived = bodyBytes; tm.countOfResponseBodyBytesAfterDecoding = bodyBytes
        tm.countOfRequestBodyBytesSent = Int64(tm.request.httpBody?.count ?? 0)
    }
    func _deliverCached(_ c: CachedURLResponse, _ onResponse: (URLResponse) -> Bool, _ onData: (Data) -> Void) -> (Error?, cacheable: (HTTPURLResponse, URLRequest)?) {
        if let r = _current {
            let tm = URLSessionTaskTransactionMetrics(request: r)
            tm.fetchStartDate = Date(); tm.response = c.response; tm.resourceFetchType = .localCache; tm.responseEndDate = Date()
            _metrics.transactionMetrics.append(tm)
        }
        _setResponse(c.response)
        guard onResponse(c.response) else { return (URLError._make(NSURLErrorCancelled, url: c.response.url), nil) }
        if !c.data.isEmpty { _addReceived(Int64(c.data.count)); onData(c.data) }
        return (nil, nil)
    }
    func _setResponse(_ r: URLResponse) {
        _lock.lock(); _response = r; _expectedReceive = r.expectedContentLength + _resumeOffset; _lock.unlock()
        let total = r.expectedContentLength < 0 ? Int64(-1) : r.expectedContentLength + _resumeOffset
        progress.totalUnitCount = total
        progress.completedUnitCount = _resumeOffset
    }
    func _addReceived(_ n: Int64) {
        _lock.lock(); _received += n; let r = _received; _lock.unlock()
        progress.completedUnitCount = r + _resumeOffset
    }
    /// bytes a resumed download already had
    var _resumeOffset: Int64 = 0
    var _extraHeaders: [(String, String)] = []
    func _store(_ c: (HTTPURLResponse, URLRequest)?, data: Data, dataTask: URLSessionDataTask?) {
        guard let (resp, req) = c, let cache = _session.configuration.urlCache else { return }
        var proposed: CachedURLResponse? = CachedURLResponse(response: resp, data: data, userInfo: nil, storagePolicy: .allowed)
        if let dt = dataTask, _onComplete == nil, _dataCompletionHandlerSet == false, let d = _sessionTaskDelegate as? URLSessionDataDelegate, let p = proposed {
            let sem = DispatchSemaphore(value: 0), box = _URLBox<CachedURLResponse?>(p)
            _session.delegateQueue.addOperation { d.urlSession(self._session, dataTask: dt, willCacheResponse: p) { r in box.value = r; sem.signal() } }
            sem.wait()
            proposed = box.value
        }
        if let p = proposed { cache.storeCachedResponse(p, for: req) }
    }
    var _dataCompletionHandlerSet: Bool { false }

    static func _loadLocal(_ url: URL) -> (URLResponse, Data)? {
        if url.isFileURL {
            guard let d = FileManager.default.contents(atPath: url.path) else { return nil }
            return (URLResponse(url: url, mimeType: _mimeForExtension(url.pathExtension), expectedContentLength: d.count, textEncodingName: nil), d)
        }
        // data:[<mediatype>][;base64],<data>
        let s = url.absoluteString
        guard let comma = s.firstIndex(of: ",") else { return nil }
        let meta = s[s.index(s.startIndex, offsetBy: 5)..<comma]
        let payload = String(s[s.index(after: comma)...])
        let isBase64 = meta.hasSuffix(";base64")
        let type = meta.split(separator: ";").first.map(String.init) ?? ""
        let charset = meta.split(separator: ";").dropFirst().first { $0.hasPrefix("charset=") }.map { String($0.dropFirst(8)) }
        let data: Data?
        if isBase64 { data = Data(base64Encoded: payload.removingPercentEncoding ?? payload, options: .ignoreUnknownCharacters) }
        else { data = (payload.removingPercentEncoding ?? payload).data(using: .utf8) }
        guard let data else { return nil }
        return (URLResponse(url: url, mimeType: type.isEmpty ? "text/plain" : type.lowercased(), expectedContentLength: data.count,
                            textEncodingName: charset ?? (type.isEmpty ? "us-ascii" : nil)), data)
    }
    static func _mimeForExtension(_ e: String) -> String {
        switch e.lowercased() {
        case "json": return "application/json"
        case "txt", "text": return "text/plain"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "text/javascript"
        case "xml", "plist": return "application/xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "mp4": return "video/mp4"
        default: return "application/octet-stream"
        }
    }
    /// "HTTP/1.1 200 OK\r\nName: value\r\n..." -> ("HTTP/1.1", [(name, value)])
    static func _parseHeaders(_ raw: String) -> (String?, [(String, String)]) {
        var version: String? = nil, out: [(String, String)] = []
        for (i, line) in raw.split(whereSeparator: { $0 == "\r\n" || $0 == "\n" || $0 == "\r" }).enumerated() {
            if i == 0 && line.hasPrefix("HTTP/") { version = line.split(separator: " ").first.map(String.init); continue }
            guard let c = line.firstIndex(of: ":") else { continue }
            out.append((String(line[..<c]).trimmingCharacters(in: .whitespaces), String(line[line.index(after: c)...]).trimmingCharacters(in: .whitespaces)))
        }
        return (version, out)
    }
    /// fresh by Cache-Control max-age / Expires, else 10% of the time since Last-Modified (RFC 9111 heuristics)
    static func _isFresh(_ c: CachedURLResponse) -> Bool {
        guard let h = c.response as? HTTPURLResponse else { return true }
        let cc = (h.value(forHTTPHeaderField: "Cache-Control") ?? "").lowercased()
        if _urlContains(cc, "no-cache") || _urlContains(cc, "no-store") { return false }
        let age = Date().timeIntervalSince(c._stored) + (Double(h.value(forHTTPHeaderField: "Age") ?? "") ?? 0)
        for part in cc.split(separator: ",") {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.hasPrefix("max-age="), let n = Double(p.dropFirst(8)) { return age < n }
        }
        if let e = h.value(forHTTPHeaderField: "Expires") { return (HTTPCookie._parseDate(e) ?? .distantPast) > Date() }
        if let lm = h.value(forHTTPHeaderField: "Last-Modified").flatMap(HTTPCookie._parseDate) {
            return age < c._stored.timeIntervalSince(lm) * 0.1
        }
        return false
    }
    /// "<app name>/<build> isim" (isim does not claim to be CFNetwork)
    static let _userAgent: String = {
        let info = Bundle.main.infoDictionary ?? [:]
        let name = (info["CFBundleName"] as? String) ?? (info["CFBundleExecutable"] as? String) ?? ProcessInfo.processInfo.processName
        let build = (info["CFBundleVersion"] as? String) ?? "1"
        return "\(name.replacingOccurrences(of: " ", with: ""))/\(build) isim"
    }()
    static var _acceptLanguage: String {
        let langs = Locale.preferredLanguages.prefix(4)
        if langs.isEmpty { return "en-US,en;q=0.9" }
        return langs.enumerated().map { i, l in i == 0 ? l : "\(l);q=\(String(format: "%.1f", 1.0 - Double(i) * 0.1))" }.joined(separator: ", ")
    }
}

final class _URLBox<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

@objc(NSURLSessionDataTask) open class URLSessionDataTask: URLSessionTask, @unchecked Sendable {
    var _dataCompletion: (@Sendable (Data?, URLResponse?, Error?) -> Void)?
    var _uploadBody: Data?
    var _uploadFile: URL?
    override var _dataCompletionHandlerSet: Bool { _dataCompletion != nil }

    override func _main() {
        var body = _uploadBody
        if let f = _uploadFile {
            guard let d = FileManager.default.contents(atPath: f.path) else { _finish(URLError._make(NSURLErrorFileDoesNotExist, url: f)); return }
            body = d
        }
        // collect the body for a completion handler or an internal consumer that is not streaming
        let collect = _dataCompletion != nil || (_onComplete != nil && _onData == nil)
        let keep = collect || cacheableHint(self)
        var buffer = Data()
        let dataDelegate = _dataCompletion != nil || _onComplete != nil ? nil : _sessionTaskDelegate as? URLSessionDataDelegate
        let (err, cacheable) = _load(body: body, response: { r in
            if let c = self._onResponse { c(r); return true }
            guard let d = dataDelegate else { return true }
            let sem = DispatchSemaphore(value: 0), box = _URLBox<URLSession.ResponseDisposition>(.allow)
            self._session.delegateQueue.addOperation { d.urlSession(self._session, dataTask: self, didReceive: r) { box.value = $0; sem.signal() } }
            sem.wait()
            return box.value != .cancel
        }, data: { chunk in
            if let c = self._onData { c(chunk) }
            if keep { buffer.append(chunk) }
            if let d = dataDelegate { self._onQueue { d.urlSession(self._session, dataTask: self, didReceive: chunk) } }
        })
        if err == nil { _store(cacheable, data: buffer, dataTask: self) }
        if collect { _result = buffer }
        _finish(err)
    }
    override func _deliverCompletion(_ error: Error?) {
        guard let c = _dataCompletion else { super._deliverCompletion(error); return }
        let resp = response, data = _result
        _session.delegateQueue.addOperation { c(error == nil ? (data ?? Data()) : nil, resp, error) }
    }
}
/// buffer the body when the response may be cached (GET with a cache), so delegate-based tasks can store it too
private func cacheableHint(_ t: URLSessionTask) -> Bool {
    t._session.configuration.urlCache != nil && (t.originalRequest?.httpMethod ?? "GET") == "GET"
}

@objc(NSURLSessionUploadTask) open class URLSessionUploadTask: URLSessionDataTask, @unchecked Sendable {
    /// iOS 17: resumable uploads are not supported by isim
    open func cancel(byProducingResumeData completionHandler: @escaping @Sendable (Data?) -> Void) { cancel(); completionHandler(nil) }
}

@objc(NSURLSessionDownloadTask) open class URLSessionDownloadTask: URLSessionTask, @unchecked Sendable {
    var _downloadCompletion: (@Sendable (URL?, URLResponse?, Error?) -> Void)?
    var _location: URL?

    /// resume data: a property list with the URL, the partial file and the validators (ETag / Last-Modified),
    /// kept like CFNetwork does so downloadTask(withResumeData:) continues with an HTTP Range request
    var _keepPartial = false
    var _partialPath: String?
    var _resumeData: Data?
    open func cancel(byProducingResumeData completionHandler: @escaping @Sendable (Data?) -> Void) {
        _lock.lock(); _keepPartial = true; _lock.unlock()
        _resumeWaiter = completionHandler
        cancel()
    }
    var _resumeWaiter: (@Sendable (Data?) -> Void)?
    func _makeResumeData(_ path: String, written: Int64) -> Data? {
        guard written > 0, let url = (_current ?? originalRequest)?.url, let r = response as? HTTPURLResponse else { return nil }
        let etag = r.value(forHTTPHeaderField: "ETag"), lm = r.value(forHTTPHeaderField: "Last-Modified")
        guard etag != nil || lm != nil, (r.value(forHTTPHeaderField: "Accept-Ranges") ?? "bytes") != "none" else { return nil }
        var d: [String: Any] = ["NSURLSessionDownloadURL": url.absoluteString, "NSURLSessionResumeBytesReceived": NSNumber(value: written),
                                "NSURLSessionResumeInfoTempFileName": (path as NSString).lastPathComponent, "NSURLSessionResumeInfoLocalPath": path,
                                "NSURLSessionResumeInfoVersion": NSNumber(value: 2)]
        if let etag { d["NSURLSessionResumeEntityTag"] = etag }
        if let lm { d["NSURLSessionResumeServerDownloadDate"] = lm }
        if let tot = Optional(countOfBytesExpectedToReceive), tot > 0 { d["NSURLSessionResumeExpectedLength"] = NSNumber(value: tot) }
        return try? PropertyListSerialization.data(fromPropertyList: d, format: .xml, options: 0)
    }

    override func _main() {
        var tmp = NSTemporaryDirectory() + "/CFNetworkDownload_\(UUID().uuidString.prefix(8)).tmp"
        var mode = "wb"
        if let rd = _resumeData, let plist = try? PropertyListSerialization.propertyList(from: rd, options: [], format: nil) as? [String: Any],
           let path = plist["NSURLSessionResumeInfoLocalPath"] as? String, FileManager.default.fileExists(atPath: path) {
            let have = (plist["NSURLSessionResumeBytesReceived"] as? NSNumber)?.int64Value ?? 0
            tmp = path; mode = "ab"
            _resumeOffset = have
            _extraHeaders = [("Range", "bytes=\(have)-")]
            if let e = plist["NSURLSessionResumeEntityTag"] as? String { _extraHeaders.append(("If-Range", e)) }
            else if let lm = plist["NSURLSessionResumeServerDownloadDate"] as? String { _extraHeaders.append(("If-Range", lm)) }
        }
        _partialPath = tmp
        guard let f = fopen(tmp, mode) else { _finish(URLError._make(NSURLErrorCannotWriteToFile, url: originalRequest?.url)); return }
        let dd = _downloadCompletion != nil || _onComplete != nil ? nil : _sessionTaskDelegate as? URLSessionDownloadDelegate
        var written: Int64 = _resumeOffset
        var writeFailed = false
        let (err0, _) = _load(body: nil, response: { r in
            // a resumed download: 206 continues the file; a full 200 starts over
            if self._resumeOffset > 0 {
                if (r as? HTTPURLResponse)?.statusCode == 206 {
                    let off = self._resumeOffset, exp = r.expectedContentLength < 0 ? Int64(-1) : r.expectedContentLength + off
                    if let d = dd { self._onQueue { d.urlSession(self._session, downloadTask: self, didResumeAtOffset: off, expectedTotalBytes: exp) } }
                } else {
                    fclose(fopen(tmp, "wb")); fseek(f, 0, SEEK_SET); written = 0; self._resumeOffset = 0   /* the server sent the whole file: start over */
                    if let d = dd { self._onQueue { d.urlSession(self._session, downloadTask: self, didResumeAtOffset: 0, expectedTotalBytes: r.expectedContentLength) } }
                }
            }
            self._onResponse?(r); return true
        }, data: { chunk in
            let n = chunk.withUnsafeBytes { fwrite($0.baseAddress, 1, $0.count, f) }
            if n != chunk.count { writeFailed = true }
            written += Int64(chunk.count)
            if let d = dd {
                let total = written, expected = self.countOfBytesExpectedToReceive
                self._onQueue { d.urlSession(self._session, downloadTask: self, didWriteData: Int64(chunk.count), totalBytesWritten: total, totalBytesExpectedToWrite: expected) }
            }
        })
        fclose(f)
        var err = err0 ?? (writeFailed ? URLError._make(NSURLErrorCannotWriteToFile, url: originalRequest?.url) : nil)
        _lock.lock(); let keep = _keepPartial; _lock.unlock()
        let resume = (keep || (err != nil && !_isCancelled)) ? _makeResumeData(tmp, written: written) : nil
        if let w = _resumeWaiter { _resumeWaiter = nil; let r = resume; _session.delegateQueue.addOperation { w(r) } }
        if let resume, err != nil, !_isCancelled, var info = (err as? URLError)?.errorUserInfo {   /* a failed download carries resume data like iOS */
            info[NSURLSessionDownloadTaskResumeData] = resume
            err = URLError(URLError.Code(rawValue: (err as! URLError).errorCode), userInfo: info)
        }
        if err != nil || _isCancelled { if resume == nil { unlink(tmp) } } else { _location = URL(fileURLWithPath: tmp) }
        _downloadDelegate = dd
        _finish(err)
    }
    var _downloadDelegate: URLSessionDownloadDelegate?
    override func _deliverCompletion(_ error: Error?) {
        let loc = error == nil ? _location : nil
        if let c = _downloadCompletion {
            let resp = response
            _onQueue { c(loc, resp, error); if let loc { unlink(loc.path) } }     // the file is removed when the handler returns
            return
        }
        if let loc, let d = _downloadDelegate {
            _onQueue { d.urlSession(self._session, downloadTask: self, didFinishDownloadingTo: loc); unlink(loc.path) }
        }
        super._deliverCompletion(error)
    }
}

// MARK: - async/await
extension URLSession {
    func _run<T: URLSessionTask, R>(_ task: T, delegate: URLSessionTaskDelegate?, _ result: @escaping (T, Error?) -> Result<R, Error>) async throws -> R {
        let box = _URLBox<T?>(task)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (k: CheckedContinuation<R, Error>) in
                if let delegate { task.delegate = delegate }
                task._onComplete = { err in k.resume(with: result(task, err)) }
                task.resume()
            }
        } onCancel: { box.value?.cancel() }
    }
    func _asyncData(_ request: URLRequest, body: Data? = nil, file: URL? = nil, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
        let t: URLSessionDataTask = body != nil || file != nil ? _add(URLSessionUploadTask(self, request)) : _add(URLSessionDataTask(self, request))
        t._uploadBody = body; t._uploadFile = file
        return try await _run(t, delegate: delegate) { task, err in
            if let err { return .failure(err) }
            guard let r = task.response else { return .failure(URLError(.badServerResponse)) }
            return .success((task._result ?? Data(), r))
        }
    }
    public func data(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        try await _asyncData(request, delegate: delegate)
    }
    public func data(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        try await _asyncData(URLRequest(url: url), delegate: delegate)
    }
    public func upload(for request: URLRequest, from bodyData: Data, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        try await _asyncData(request, body: bodyData, delegate: delegate)
    }
    public func upload(for request: URLRequest, fromFile fileURL: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (Data, URLResponse) {
        try await _asyncData(request, file: fileURL, delegate: delegate)
    }
    /// The file is not deleted: move it or read it before it is cleaned up with the temporary directory.
    public func download(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (URL, URLResponse) {
        let t = _add(URLSessionDownloadTask(self, request))
        return try await _run(t, delegate: delegate) { task, err in
            if let err { return .failure(err) }
            guard let u = task._location, let r = task.response else { return .failure(URLError(.badServerResponse)) }
            return .success((u, r))
        }
    }
    public func download(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (URL, URLResponse) {
        try await download(for: URLRequest(url: url), delegate: delegate)
    }

    /// Streams the body: returns once the response headers arrive.
    public func bytes(for request: URLRequest, delegate: URLSessionTaskDelegate? = nil) async throws -> (AsyncBytes, URLResponse) {
        let t = _add(URLSessionDataTask(self, request))
        if let delegate { t.delegate = delegate }
        let (stream, cont) = AsyncThrowingStream<Data, Error>.makeStream()
        let started = _URLBox<CheckedContinuation<URLResponse, Error>?>(nil)
        let lock = NSLock()
        func takeStarted() -> CheckedContinuation<URLResponse, Error>? { lock.lock(); defer { lock.unlock() }; let k = started.value; started.value = nil; return k }
        let response: URLResponse = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (k: CheckedContinuation<URLResponse, Error>) in
                lock.lock(); started.value = k; lock.unlock()
                t._onResponse = { r in takeStarted()?.resume(returning: r) }
                t._onData = { cont.yield($0) }
                t._onComplete = { err in
                    if let err { takeStarted()?.resume(throwing: err); cont.finish(throwing: err) } else { cont.finish() }
                }
                t.resume()
            }
        } onCancel: { t.cancel() }
        cont.onTermination = { reason in if case .cancelled = reason { t.cancel() } }
        return (AsyncBytes(task: t, stream: stream), response)
    }
    public func bytes(from url: URL, delegate: URLSessionTaskDelegate? = nil) async throws -> (AsyncBytes, URLResponse) {
        try await bytes(for: URLRequest(url: url), delegate: delegate)
    }

    /// The body of a `bytes(from:)` response, byte by byte (read in chunks underneath).
    public struct AsyncBytes: AsyncSequence, @unchecked Sendable {
        public typealias Element = UInt8
        public let task: URLSessionDataTask
        let stream: AsyncThrowingStream<Data, Error>
        init(task: URLSessionDataTask, stream: AsyncThrowingStream<Data, Error>) { self.task = task; self.stream = stream }
        public struct AsyncIterator: AsyncIteratorProtocol {
            var source: AsyncThrowingStream<Data, Error>.AsyncIterator
            var chunk = Data(), index = 0
            public mutating func next() async throws -> UInt8? {
                while index >= chunk.count {
                    guard let c = try await source.next() else { return nil }
                    chunk = c; index = 0
                }
                defer { index += 1 }
                return chunk[index]
            }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(source: stream.makeAsyncIterator()) }
    }
}

/// Lines of a UTF-8 byte sequence (`bytes.lines`). Like Apple's, line breaks are \n, \r or \r\n and empty lines are skipped.
public struct AsyncLineSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = String
    let base: Base
    public struct AsyncIterator: AsyncIteratorProtocol {
        var source: Base.AsyncIterator
        var line: [UInt8] = []
        var done = false
        public mutating func next() async throws -> String? {
            while !done {
                guard let b = try await source.next() else { done = true; break }
                if b == 0x0A || b == 0x0D {
                    if line.isEmpty { continue }
                    defer { line.removeAll(keepingCapacity: true) }
                    return String(decoding: line, as: UTF8.self)
                }
                line.append(b)
            }
            if line.isEmpty { return nil }
            defer { line = [] }
            return String(decoding: line, as: UTF8.self)
        }
    }
    public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(source: base.makeAsyncIterator()) }
}
extension AsyncSequence where Element == UInt8 {
    public var lines: AsyncLineSequence<Self> { AsyncLineSequence(base: self) }
}

// MARK: - Combine
extension URLSession {
    public func dataTaskPublisher(for url: URL) -> DataTaskPublisher { DataTaskPublisher(request: URLRequest(url: url), session: self) }
    public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher { DataTaskPublisher(request: request, session: self) }

    /// Starts the data task when demand arrives; cancelling the subscription cancels the task.
    public struct DataTaskPublisher: Publisher, @unchecked Sendable {
        public typealias Output = (data: Data, response: URLResponse)
        public typealias Failure = URLError
        public let request: URLRequest
        public let session: URLSession
        public init(request: URLRequest, session: URLSession) { self.request = request; self.session = session }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == URLError {
            subscriber.receive(subscription: _DataTaskSubscription(subscriber, request: request, session: session))
        }
    }
}
final class _DataTaskSubscription<S: Subscriber>: Subscription, @unchecked Sendable where S.Input == URLSession.DataTaskPublisher.Output, S.Failure == URLError {
    let lock = NSLock()
    var downstream: S?
    var task: URLSessionDataTask?
    let request: URLRequest
    let session: URLSession
    init(_ s: S, request: URLRequest, session: URLSession) { downstream = s; self.request = request; self.session = session }
    func request(_ demand: Subscribers.Demand) {
        guard demand > 0 else { return }
        lock.lock()
        guard downstream != nil, task == nil else { lock.unlock(); return }
        let t = session._add(URLSessionDataTask(session, request))
        task = t
        lock.unlock()
        t._onComplete = { [weak self] err in
            guard let self else { return }
            self.lock.lock(); let s = self.downstream; self.downstream = nil; self.lock.unlock()
            guard let s else { return }
            if let err { s.receive(completion: .failure(err as? URLError ?? URLError(.unknown))); return }
            guard let r = t.response else { s.receive(completion: .failure(URLError(.badServerResponse))); return }
            _ = s.receive((data: t._result ?? Data(), response: r))
            s.receive(completion: .finished)
        }
        t.resume()
    }
    func cancel() {
        lock.lock(); downstream = nil; let t = task; lock.unlock()
        t?.cancel()
    }
}


// MARK: - background sessions (see the top of this file)
enum _IsimBackgroundSessions {
    nonisolated(unsafe) static var appInBackground = false
    nonisolated(unsafe) static var sessions: [String: WeakSession] = [:]
    nonisolated(unsafe) static var pendingWakes = 0          /* completion handlers not called yet (keeps the app busy) */
    static let lock = NSLock()
    final class WeakSession { weak var session: URLSession?; init(_ s: URLSession) { session = s } }
    nonisolated(unsafe) static var observing = false

    static func register(_ s: URLSession) {
        guard let id = s.configuration.identifier else { return }
        lock.lock(); sessions[id] = WeakSession(s); lock.unlock()
        observe()
        restore(s, id)
    }
    /// the app's state (UIKit's notifications, by name: Foundation cannot import UIKit)
    static func observe() {
        lock.lock(); let first = !observing; observing = true; lock.unlock()
        guard first else { return }
        if ProcessInfo.processInfo.environment["ISIM_LAUNCH_BACKGROUND"] == "1" { appInBackground = true }   // launched in the background
        let nc = NotificationCenter.default
        _ = nc.addObserver(forName: Notification.Name("UIApplicationDidEnterBackgroundNotification"), object: nil, queue: nil) { _ in appInBackground = true }
        _ = nc.addObserver(forName: Notification.Name("UIApplicationWillEnterForegroundNotification"), object: nil, queue: nil) { _ in
            appInBackground = false
            for s in live() { flush(s, finish: false) }                         // back in front: everything held, now
        }
        _ = nc.addObserver(forName: Notification.Name("_IsimBackgroundQuery"), object: nil, queue: nil) { n in
            guard let q = n.object as? NSMutableDictionary else { return }
            if busy() { q.setObject(NSNumber(value: true), forKey: "transfer" as NSString) }                                    // keeps the app from being suspended
        }
        _ = nc.addObserver(forName: Notification.Name("_IsimBackgroundSessionsQuery"), object: nil, queue: nil) { n in   // UIKit: which sessions exist
            guard let q = n.object as? NSMutableDictionary else { return }
            q.setObject(live().compactMap { $0.configuration.identifier } as NSArray, forKey: "sessions" as NSString)
        }
    }
    static func live() -> [URLSession] { lock.lock(); defer { lock.unlock() }; return sessions.values.compactMap(\.session) }
    static func busy() -> Bool {
        lock.lock(); let w = pendingWakes; lock.unlock()
        return w > 0 || live().contains { s in s._lock.lock(); defer { s._lock.unlock() }; return !s._tasks.isEmpty || s._waking }
    }
    /// a background session with nothing left to run while the app is in the background: wake the app (UIKit)
    static func idleCheck(_ s: URLSession) {
        guard appInBackground, let id = s.configuration.identifier else { return }
        s._lock.lock()
        let idle = s._tasks.isEmpty && !s._held.isEmpty && !s._waking
        if idle { s._waking = true }
        s._lock.unlock()
        guard idle else { return }
        // relaunched for this session and the app already heard about it (UIKit): its events, without a second wake
        let handled = (ProcessInfo.processInfo.environment["ISIM_URLSESSION_HANDLED"] ?? "").split(separator: ",").contains { $0 == id }
        if handled {
            unsetHandled(id)
            NSLog("isim: background URL session %@ finished", id)
            flush(s, finish: true)
            return
        }
        lock.lock(); pendingWakes += 1; lock.unlock()
        NSLog("isim: background URL session %@ finished: waking the app", id)
        let done: @convention(block) () -> Void = {
            lock.lock(); pendingWakes = max(0, pendingWakes - 1); lock.unlock()
            NSLog("isim: background URL session %@ events handled", id)
        }
        let deliver: @convention(block) () -> Void = { flush(s, finish: true) }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("_IsimBackgroundURLSessionEvents"), object: id as NSString,
                                            userInfo: ["completion": done as AnyObject, "deliver": deliver as AnyObject])
        }
    }
    static func unsetHandled(_ id: String) {
        let rest = (ProcessInfo.processInfo.environment["ISIM_URLSESSION_HANDLED"] ?? "").split(separator: ",").filter { $0 != id }
        if rest.isEmpty { unsetenv("ISIM_URLSESSION_HANDLED") } else { setenv("ISIM_URLSESSION_HANDLED", rest.joined(separator: ","), 1) }
    }
    /// the held events, in order, then (when woken) urlSessionDidFinishEvents
    static func flush(_ s: URLSession, finish: Bool) {
        s._lock.lock(); let held = s._held; s._held = []; s._waking = false; let d = s._delegate; s._lock.unlock()
        guard !held.isEmpty || finish else { return }
        s.delegateQueue.addOperation {
            for body in held { body() }
            if finish { d?.urlSessionDidFinishEvents(forBackgroundURLSession: s) }
        }
    }
    // MARK: persistence (an app terminated during transfers starts them again when it recreates the session)
    static func file(_ id: String) -> String {
        let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        return (caches as NSString).appendingPathComponent("isim-nsurlsessiond/\(id.replacingOccurrences(of: "/", with: "_")).plist")
    }
    static func save(_ s: URLSession) {
        guard let id = s.configuration.identifier else { return }
        s._lock.lock()
        let entries: [[String: String]] = s._tasks.values.sorted { $0._id < $1._id }.compactMap { t in
            guard let url = t.originalRequest?.url?.absoluteString else { return nil }
            if let u = t as? URLSessionUploadTask, let f = u._uploadFile { return ["kind": "upload", "url": url, "file": f.path, "method": t.originalRequest?.httpMethod ?? "POST"] }
            if t is URLSessionDownloadTask { return ["kind": "download", "url": url] }
            return nil
        }
        s._lock.unlock()
        let path = file(id)
        if entries.isEmpty { unlink(path); return }
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        if let d = try? PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0) { FileManager.default.createFile(atPath: path, contents: d, attributes: nil) }
    }
    static func restore(_ s: URLSession, _ id: String) {
        guard let d = FileManager.default.contents(atPath: file(id)),
              let saved = (try? PropertyListSerialization.propertyList(from: d, options: [], format: nil)) as? [[String: String]], !saved.isEmpty else { return }
        unlink(file(id))
        NSLog("isim: background URL session %@: starting %d unfinished transfer(s) again", id, saved.count)
        for e in saved {
            guard let url = e["url"].flatMap(URL.init(string:)) else { continue }
            if e["kind"] == "upload", let f = e["file"] {
                var r = URLRequest(url: url); r.httpMethod = e["method"] ?? "POST"
                s.uploadTask(with: r, fromFile: URL(fileURLWithPath: f)).resume()
            } else {
                s.downloadTask(with: url).resume()
            }
        }
    }
}

// MARK: - TLS probe (server certificates for the trust challenge, client-certificate requests)
struct _TLSProbe {
    var chain: [[UInt8]]
    var pin: String?
    var clientCertificateRequested: Bool
    var distinguishedNames: [Data]
}
extension URLSession {
    /// the server's certificates and client-certificate request, from one handshake per server and session
    func _probe(host: String, port: Int, timeout: TimeInterval) -> _TLSProbe? {
        let key = "\(host.lowercased()):\(port)"
        _lock.lock(); let known = _tlsProbes[key]; _lock.unlock()
        if let known { return known }
        var chain = [UInt8](repeating: 0, count: 65536), lens = [Int](repeating: 0, count: 16), n: Int32 = 0
        var dn = [UInt8](repeating: 0, count: 16384), dnLens = [Int](repeating: 0, count: 32), ndn: Int32 = 0
        var pin = [CChar](repeating: 0, count: 128), err = [CChar](repeating: 0, count: 256), asked: Int32 = 0
        let ok = isim_tls_probe(host, Int32(port), timeout, &chain, chain.count, &lens, 16, &n, &pin, 128, &asked,
                                &dn, dn.count, &dnLens, 32, &ndn, &err, 256)
        guard ok == 1 else { return nil }
        var certs: [[UInt8]] = [], at = 0
        for i in 0..<Int(n) { certs.append(Array(chain[at..<(at + lens[i])])); at += lens[i] }
        var names: [Data] = []; at = 0
        for i in 0..<Int(ndn) { names.append(Data(dn[at..<(at + dnLens[i])])); at += dnLens[i] }
        let pinText = String(cString: pin)
        let probe = _TLSProbe(chain: certs, pin: pinText.isEmpty ? nil : pinText, clientCertificateRequested: asked != 0, distinguishedNames: names)
        _lock.lock(); _tlsProbes[key] = probe; _lock.unlock()
        return probe
    }
}
