// isim AVFoundation: AVAssetResourceLoader — media from custom URL schemes, supplied by the app's delegate.
// Self-authored, iOS API names. Like iOS, isim first asks for the content information and two bytes, then for the
// resource in ranges (1 MB each; one request to the end when the length is unknown). Adapted: the bytes are collected
// into a file in the app's temporary directory and the host's ffmpeg plays that file once it is complete (iOS
// streams the ranges as it plays). Loading starts when the asset is first probed (an AVPlayerItem loads it off the
// main thread).
import Foundation
import UniformTypeIdentifiers

@objc public protocol AVAssetResourceLoaderDelegate: NSObjectProtocol {
    @objc optional func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool
    @objc optional func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool
    @objc(resourceLoader:didCancelLoadingRequest:) optional func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest)
    @objc optional func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool
    @objc(resourceLoader:didCancelAuthenticationChallenge:) optional func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel authenticationChallenge: URLAuthenticationChallenge)
}

@objc(AVAssetResourceLoader) open class AVAssetResourceLoader: NSObject, @unchecked Sendable {
    open private(set) weak var delegate: AVAssetResourceLoaderDelegate?
    open private(set) var delegateQueue: DispatchQueue?
    open var preloadsEligibleContentKeys = false
    override init() { super.init() }
    open func setDelegate(_ delegate: AVAssetResourceLoaderDelegate?, queue delegateQueue: DispatchQueue?) {
        self.delegate = delegate; self.delegateQueue = delegateQueue
    }

    static let chunk = 1 << 20
    /// Fetches `url` through the delegate into a temporary file; nil (with the error) when the delegate declines or fails.
    func _load(_ url: URL) -> (URL?, Error?) {
        guard let d = delegate, let q = delegateQueue else {
            return (nil, NSError(domain: AVFoundationErrorDomain, code: -11828,
                                 userInfo: [NSLocalizedDescriptionKey: "Cannot Open", NSLocalizedFailureReasonErrorKey: "no resource loader delegate for \(url.scheme ?? "") URLs"]))
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("isim-resource-loader", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let file = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        guard let out = FileHandle(forWritingAtPath: file.path) else { return (nil, nil) }
        defer { try? out.close() }
        /// one request; false when it failed or was declined
        func run(_ r: AVAssetResourceLoadingRequest) -> Bool {
            let done = DispatchSemaphore(value: 0)
            r._done = { done.signal() }
            var accepted = false
            q.async {
                accepted = d.resourceLoader?(self, shouldWaitForLoadingOfRequestedResource: r) ?? false
                if !accepted { r._declined = true; done.signal() }
            }
            if Thread.isMainThread {                        // the delegate may answer on the main queue
                while done.wait(timeout: .now()) == .timedOut { RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01)) }
            } else if done.wait(timeout: .now() + 120) == .timedOut {
                r._cancel()
                q.async { d.resourceLoader?(self, didCancel: r) }
                return false
            }
            return !r._declined && r._error == nil
        }
        // content information and the first bytes, as iOS asks
        let first = AVAssetResourceLoadingRequest(url: url, offset: 0, length: 2, toEnd: false, info: true)
        guard run(first) else { return (nil, first._error ?? Self._declined(url)) }
        out.write(first._received)
        let info = first.contentInformationRequest!
        var offset = Int64(first._received.count)
        if info.contentLength > 0 {
            while offset < info.contentLength {
                let n = Int(min(Int64(Self.chunk), info.contentLength - offset))
                let r = AVAssetResourceLoadingRequest(url: url, offset: offset, length: n, toEnd: false, info: false)
                guard run(r) else { return (nil, r._error ?? Self._declined(url)) }
                guard !r._received.isEmpty else { break }
                out.write(r._received)
                offset += Int64(r._received.count)
            }
        } else {
            let r = AVAssetResourceLoadingRequest(url: url, offset: offset, length: Int.max, toEnd: true, info: false)
            guard run(r) else { return (nil, r._error ?? Self._declined(url)) }
            out.write(r._received)
        }
        return (file, nil)
    }
    static func _declined(_ url: URL) -> NSError {
        NSError(domain: AVFoundationErrorDomain, code: -11828,
                userInfo: [NSLocalizedDescriptionKey: "Cannot Open", NSLocalizedFailureReasonErrorKey: "the resource loader delegate did not load \(url.absoluteString)"])
    }
}

@objc(AVAssetResourceLoadingRequestor) open class AVAssetResourceLoadingRequestor: NSObject, @unchecked Sendable {
    open var providesExpiredSessionReports: Bool { false }
}

@objc(AVAssetResourceLoadingRequest) open class AVAssetResourceLoadingRequest: NSObject, @unchecked Sendable {
    public let request: URLRequest
    public let contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?
    public let dataRequest: AVAssetResourceLoadingDataRequest?
    open var response: URLResponse?
    open var redirect: URLRequest?
    open var requestor: AVAssetResourceLoadingRequestor { AVAssetResourceLoadingRequestor() }
    open private(set) var isFinished = false
    open private(set) var isCancelled = false
    var _received = Data()
    var _error: Error?
    var _declined = false
    var _done: (() -> Void)?
    let _lock = NSLock()
    init(url: URL, offset: Int64, length: Int, toEnd: Bool, info: Bool) {
        var r = URLRequest(url: url)
        if !toEnd { r.setValue("bytes=\(offset)-\(offset + Int64(length) - 1)", forHTTPHeaderField: "Range") }
        request = r
        contentInformationRequest = info ? AVAssetResourceLoadingContentInformationRequest() : nil
        dataRequest = AVAssetResourceLoadingDataRequest(offset: offset, length: length, toEnd: toEnd)
        super.init()
        dataRequest?._owner = self
    }
    open func finishLoading() { _finish(nil) }
    open func finishLoading(with error: Error?) { _finish(error ?? NSError(domain: AVFoundationErrorDomain, code: -11800)) }
    open func finishLoading(with response: URLResponse?, data: Data?, redirect: URLRequest?) {
        self.response = response; self.redirect = redirect
        if let data { dataRequest?.respond(with: data) }
        _finish(nil)
    }
    func _finish(_ error: Error?) {
        _lock.lock()
        guard !isFinished, !isCancelled else { _lock.unlock(); return }
        isFinished = true; _error = error
        let done = _done; _done = nil
        _lock.unlock()
        done?()
    }
    func _cancel() { _lock.lock(); isCancelled = true; _done = nil; _lock.unlock() }
    func _append(_ d: Data) { _lock.lock(); if !isFinished && !isCancelled { _received.append(d) }; _lock.unlock() }
}

@objc(AVAssetResourceLoadingContentInformationRequest) open class AVAssetResourceLoadingContentInformationRequest: NSObject, @unchecked Sendable {
    /// a UTI ("public.mpeg-4", "com.apple.quicktime-movie", ...)
    open var contentType: String?
    open var allowedContentTypes: [String]? { AVURLAsset.audiovisualTypes() }
    open var contentLength: Int64 = 0
    open var isByteRangeAccessSupported = false
    open var renewalDate: Date?
    open var isEntireLengthAvailableOnDemand = false
}

@objc(AVAssetResourceLoadingDataRequest) open class AVAssetResourceLoadingDataRequest: NSObject, @unchecked Sendable {
    public let requestedOffset: Int64
    public let requestedLength: Int
    public let requestsAllDataToEndOfResource: Bool
    open private(set) var currentOffset: Int64
    weak var _owner: AVAssetResourceLoadingRequest?
    init(offset: Int64, length: Int, toEnd: Bool) { requestedOffset = offset; requestedLength = length; requestsAllDataToEndOfResource = toEnd; currentOffset = offset }
    /// more of the requested bytes, in order (data beyond the requested range is dropped)
    open func respond(with data: Data) {
        var d = data
        if !requestsAllDataToEndOfResource {
            let left = Int(requestedOffset + Int64(requestedLength) - currentOffset)
            if d.count > left { d = d.prefix(max(0, left)) }
        }
        currentOffset += Int64(d.count)
        _owner?._append(d)
    }
}

@objc(AVAssetResourceRenewalRequest) open class AVAssetResourceRenewalRequest: AVAssetResourceLoadingRequest, @unchecked Sendable {}
