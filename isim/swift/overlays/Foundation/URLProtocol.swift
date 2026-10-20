// isim Foundation: URLProtocol, URLProtocolClient (self-authored, Swift API; Apple's Objective-C names). A session
// asks configuration.protocolClasses, in order, and the shared session also the classes registered with
// registerClass(_:) (the latest first), whether one of them loads a request; the first that says yes loads it instead
// of isim's own loader (URLSession.swift, _loadThroughProtocol): startLoading() runs on the task's thread, whose run
// loop runs while it loads, and the client's calls become the task's response, data, redirects and completion.
// Every member a subclass overrides is dispatched through the Objective-C runtime, so subclasses written in
// Objective-C work too (NSURLProtocol.h, unlike the other networking headers, allows subclassing).

// MARK: - URLProtocolClient

@objc(NSURLProtocolClient)
public protocol URLProtocolClient: NSObjectProtocol {
    @objc(URLProtocol:wasRedirectedToRequest:redirectResponse:)
    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse)
    @objc(URLProtocol:cachedResponseIsValid:)
    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse)
    @objc(URLProtocol:didReceiveResponse:cacheStoragePolicy:)
    func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy)
    @objc(URLProtocol:didLoadData:)
    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data)
    @objc(URLProtocolDidFinishLoading:)
    func urlProtocolDidFinishLoading(_ protocol: URLProtocol)
    @objc(URLProtocol:didFailWithError:)
    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error)
    @objc(URLProtocol:didReceiveAuthenticationChallenge:)
    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge)
    @objc(URLProtocol:didCancelAuthenticationChallenge:)
    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge)
}

extension URLCache {
    public typealias StoragePolicy = CachedURLResponse.StoragePolicy
}

// MARK: - URLProtocol

/// Foundation's NSURLProtocol (Objective-C, _URLProtocolBase here) with the Swift-typed API. Its @objc members use
/// NSURLProtocol's selectors, so URLSession, which asks protocol classes through the runtime, reaches the overrides
/// of Swift subclasses the same way it reaches those of Objective-C ones.
open class URLProtocol: _URLProtocolBase, @unchecked Sendable {
    let _request: URLRequest
    let _cachedResponse: CachedURLResponse?
    let _client: URLProtocolClient?
    weak var _task: URLSessionTask?

    @objc(initWithRequest:cachedResponse:client:)
    public required init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        _request = request; _cachedResponse = cachedResponse; _client = client
        super.init(_isimRequest: request as NSURLRequest, cachedResponse: cachedResponse, client: client)
    }
    /// iOS 8: the task's current request
    @objc(initWithTask:cachedResponse:client:)
    public convenience init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        self.init(request: task.currentRequest ?? task.originalRequest ?? URLRequest(url: URL(string: "about:blank")!),
                  cachedResponse: cachedResponse, client: client)
        _task = task
    }

    @objc open var client: URLProtocolClient? { _client }
    @objc open var request: URLRequest { _request }
    @objc open var cachedResponse: CachedURLResponse? { _cachedResponse }
    @objc open var task: URLSessionTask? { _task }

    /// whether this class loads the request (subclasses override: the base class loads nothing)
    @objc(canInitWithRequest:) open class func canInit(with request: URLRequest) -> Bool { false }
    @objc(canInitWithTask:) open class func canInit(with task: URLSessionTask) -> Bool {
        guard let r = task.currentRequest ?? task.originalRequest else { return false }
        return canInit(with: r)
    }
    /// the request as this class loads it (the base class: unchanged)
    @objc(canonicalRequestForRequest:) open class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    @objc(requestIsCacheEquivalent:toRequest:) open class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        canonicalRequest(for: a) == canonicalRequest(for: b)
    }

    // MARK: request properties (kept in the request: copies and the NSMutableURLRequest bridge carry them)
    @objc(propertyForKey:inRequest:) open class func property(forKey key: String, in request: URLRequest) -> Any? {
        request._protocolProperties[key]
    }
    @objc(setProperty:forKey:inRequest:) open class func setProperty(_ value: Any, forKey key: String, in request: NSMutableURLRequest) {
        request._r._protocolProperties[key] = value
    }
    @objc(removePropertyForKey:inRequest:) open class func removeProperty(forKey key: String, in request: NSMutableURLRequest) {
        request._r._protocolProperties[key] = nil
    }
}

extension NSURLRequest {
    /// NSURLProtocol's property methods (Foundation, Objective-C) reach the request's properties through these
    @objc(_isimProtocolProperties) var _isimProtocolProperties: [String: Any] { _r._protocolProperties }
}
extension NSMutableURLRequest {
    @objc(_isimSetProtocolProperty:forKey:) func _isimSetProtocolProperty(_ value: Any?, forKey key: String) { _r._protocolProperties[key] = value }
}

// MARK: - the client a session gives its protocols

/// the events of a protocol's load, queued for the task's thread
enum _URLProtocolEvent {
    case response(URLResponse, URLCache.StoragePolicy)
    case data(Data)
    case finished
    case failed(Error)
    case redirected(URLRequest, URLResponse)
    case cached(CachedURLResponse)
}

final class _URLProtocolSessionClient: NSObject, URLProtocolClient, @unchecked Sendable {
    let lock = NSCondition()
    var events: [_URLProtocolEvent] = []
    weak var task: URLSessionTask?
    init(task: URLSessionTask) { self.task = task }

    func post(_ e: _URLProtocolEvent) { lock.lock(); events.append(e); lock.signal(); lock.unlock() }
    /// the next event; while there is none, the calling thread's run loop runs (protocols may schedule work on it)
    func next(cancelled: () -> Bool) -> _URLProtocolEvent? {
        while true {
            lock.lock()
            if !events.isEmpty { let e = events.removeFirst(); lock.unlock(); return e }
            lock.unlock()
            if cancelled() { return nil }
            let deadline = Date(timeIntervalSinceNow: 0.05)
            if !RunLoop.current.run(mode: .default, before: deadline) {          // no run loop sources: just wait
                lock.lock()
                if events.isEmpty { _ = lock.wait(until: deadline) }
                lock.unlock()
            }
        }
    }

    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) { post(.redirected(request, redirectResponse)) }
    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) { post(.cached(cachedResponse)) }
    func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
        post(.response(response, policy))
    }
    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) { post(.data(data)) }
    func urlProtocolDidFinishLoading(_ protocol: URLProtocol) { post(.finished) }
    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error) { post(.failed(error)) }
    /// challenges go to the session's delegates; their answer goes to the challenge's sender (the protocol's)
    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {
        guard let task else { return }
        Thread.detachNewThread {
            let (disposition, credential) = task._askChallenge(challenge, sessionWide: false)
            guard let sender = challenge.sender else { return }
            switch disposition {
            case .useCredential:
                if let c = credential { sender.use(c, for: challenge) } else { sender.continueWithoutCredential(for: challenge) }
            case .cancelAuthenticationChallenge: sender.cancel(challenge)
            case .rejectProtectionSpace: sender.rejectProtectionSpaceAndContinue?(with: challenge)
            default: sender.performDefaultHandling?(for: challenge)
            }
        }
    }
    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}
