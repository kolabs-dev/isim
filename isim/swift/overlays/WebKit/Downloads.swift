// isim WebKit: downloads (WKDownload, WKDownloadDelegate), HTTP authentication challenges and camera / microphone
// permission requests. The engine (WebKitGTK) downloads the file and authenticates; the app decides through these.
// Adapted: WebKitGTK cannot resume a partial download, so isim's resume data restarts it to the same destination; the
// camera and microphone a page gets are WebKit's mock capture devices.
import UIKit

// MARK: - types

@objc public enum WKMediaCaptureType: Int, Sendable { case camera = 0, microphone, cameraAndMicrophone }
@objc public enum WKPermissionDecision: Int, Sendable { case prompt = 0, grant, deny }

@objc(WKDownloadDelegate) public protocol WKDownloadDelegate: NSObjectProtocol {
    /// where to save the file (nil cancels the download)
    @MainActor @objc(download:decideDestinationUsingResponse:suggestedFilename:completionHandler:)
    optional func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                           completionHandler: @escaping (URL?) -> Void)
    @MainActor @objc(download:decideDestinationUsingResponse:suggestedFilename:asyncCompletionHandler:)
    optional func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL?
    @MainActor @objc(download:willPerformHTTPRedirection:newRequest:decisionHandler:)
    optional func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                           decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void)
    @MainActor @objc(download:didReceiveAuthenticationChallenge:completionHandler:)
    optional func download(_ download: WKDownload, didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    @MainActor @objc(downloadDidFinish:) optional func downloadDidFinish(_ download: WKDownload)
    @MainActor @objc(download:didFailWithError:resumeData:) optional func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?)
}

/// a file the web view downloads: from startDownload(using:), or a navigation the app's policy turned into a download
@objc(WKDownload) open class WKDownload: NSObject, ProgressReporting, @unchecked Sendable {
    @objc(WKDownloadRedirectPolicy) public enum RedirectPolicy: Int, Sendable { case cancel = 0, allow }
    @objc open private(set) var originalRequest: URLRequest?
    @objc open private(set) weak var webView: WKWebView?
    @objc open weak var delegate: WKDownloadDelegate?
    @objc open private(set) var progress = Progress(totalUnitCount: -1)
    @objc open private(set) var isUserInitiated: Bool
    @objc open private(set) var originatingFrame: WKFrameInfo
    var id = 0
    var destination: URL?
    var cancelled: ((Data?) -> Void)?
    var finished = false
    @MainActor init(request: URLRequest?, webView: WKWebView?, userInitiated: Bool) {
        originalRequest = request; self.webView = webView; isUserInitiated = userInitiated
        originatingFrame = WKFrameInfo(main: true, url: webView?.url, webView: webView)
        super.init()
        progress.cancellationHandler = { [weak self] in DispatchQueue.main.async { self?.cancel(nil) } }
    }
    /// stops the download; the handler gets data that resumeDownload(fromResumeData:) restarts it with
    @objc(cancel:) open func cancel(_ completionHandler: ((Data?) -> Void)? = nil) {
        guard !finished else { completionHandler?(nil); return }
        cancelled = { d in completionHandler?(d) }
        _WKEngine.shared.send(["dlcancel", "0", String(id)])
    }
    open func cancel() async -> Data? { await withCheckedContinuation { k in cancel { k.resume(returning: $0) } } }
    /// isim's resume data: the request and the destination (a partial download is restarted)
    var resumeData: Data? {
        guard let u = originalRequest?.url else { return nil }
        var o: [String: Any] = ["NSURLDownloadURL": u.absoluteString]
        if let d = destination { o["NSURLDownloadPath"] = d.path }
        return try? PropertyListSerialization.data(fromPropertyList: o, format: .binary, options: 0)
    }
}

@MainActor enum _WKDownloads {
    static var live: [Int: WKDownload] = [:]
    /// downloads the app started, waiting for the engine's id (by request id)
    static var starting: [Int: (WKDownload) -> Void] = [:]
    static var resumeDestinations: [Int: URL] = [:]
    static func event(_ ev: String, viewID: Int, _ f: [String]) {
        guard let id = f.first.flatMap({ Int($0) }) else { return }
        switch ev {
        case "dlstart":
            guard f.count >= 4 else { return }
            let req = Int(f[1]) ?? 0, origin = f[2], o = _wkJSONObject(f[3])
            let wv = WKWebView._live(viewID)
            var rq: URLRequest?
            if let u = URL(string: o["url"] as? String ?? "") { rq = URLRequest(url: u) }
            let d = WKDownload(request: rq, webView: wv, userInitiated: origin != "api")
            d.id = id
            if let dest = resumeDestinations.removeValue(forKey: req) { d.destination = dest }
            live[id] = d
            if let done = starting.removeValue(forKey: req) { done(d); return }
            // a navigation the policy turned into a download
            guard let wv, let nd = wv.navigationDelegate else { return }
            if origin == "action" {
                let a = WKNavigationAction(sourceFrame: d.originatingFrame, targetFrame: d.originatingFrame, navigationType: .other,
                                           request: rq ?? URLRequest(url: URL(string: "about:blank")!), buttonNumber: 0)
                nd.webView?(wv, navigationAction: a, didBecome: d)
            } else {
                let u = rq?.url ?? URL(string: "about:blank")!
                let r = WKNavigationResponse(isForMainFrame: true, response: URLResponse(url: u, mimeType: nil, expectedContentLength: -1, textEncodingName: nil),
                                             canShowMIMEType: false)
                nd.webView?(wv, navigationResponse: r, didBecome: d)
            }
        case "dldest":
            guard let d = live[id], f.count >= 3 else { return }
            let o = _wkJSONObject(f[2])
            let u = URL(string: o["url"] as? String ?? "") ?? d.originalRequest?.url ?? URL(string: "about:blank")!
            let status = o["status"] as? Int ?? 0, length = o["length"] as? Int ?? -1
            let response: URLResponse = status > 0
                ? (HTTPURLResponse(url: u, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": o["mime"] as? String ?? ""].merging(length > 0 ? ["Content-Length": String(length)] : [:]) { a, _ in a }) ?? URLResponse(url: u, mimeType: nil, expectedContentLength: -1, textEncodingName: nil))
                : URLResponse(url: u, mimeType: o["mime"] as? String, expectedContentLength: length, textEncodingName: nil)
            if length > 0 { d.progress.totalUnitCount = Int64(length) }
            let answer: (URL?) -> Void = { dest in
                d.destination = dest
                _WKEngine.shared.send(["dldest", "0", String(id), dest?.path ?? ""])
            }
            if let dest = d.destination { answer(dest); return }          // a resumed download keeps its destination
            var name = f[1].isEmpty ? (u.lastPathComponent.isEmpty ? "download" : u.lastPathComponent) : f[1]
            if d.originalRequest?.url?.scheme == "data" {        // like Safari: "Unknown" with the type's extension
                let mime = (o["mime"] as? String ?? "").lowercased()
                let ext = ["text/plain": ".txt", "text/html": ".html", "application/pdf": ".pdf", "image/png": ".png", "image/jpeg": ".jpg",
                           "application/json": ".json"][mime] ?? ""
                name = "Unknown" + ext
            }
            guard let del = d.delegate else { answer(nil); return }
            if _wkHas(del, "download:decideDestinationUsingResponse:suggestedFilename:completionHandler:") {
                del.download?(d, decideDestinationUsing: response, suggestedFilename: name, completionHandler: answer)
            } else if _wkHas(del, "download:decideDestinationUsingResponse:suggestedFilename:asyncCompletionHandler:") {
                _wkAsyncCast(del).download(d, asyncDestination: response, suggestedFilename: name, completionHandler: answer)
            } else { answer(nil) }
        case "dlprogress":
            guard let d = live[id], f.count >= 3 else { return }
            if let t = Int64(f[2]), t > 0 { d.progress.totalUnitCount = t }
            d.progress.completedUnitCount = Int64(f[1]) ?? 0
        case "dldone":
            guard let d = live.removeValue(forKey: id) else { return }
            d.finished = true
            if d.progress.totalUnitCount < 0 { d.progress.totalUnitCount = d.progress.completedUnitCount }
            d.progress.completedUnitCount = d.progress.totalUnitCount
            d.delegate?.downloadDidFinish?(d)
        case "dlfail":
            guard let d = live.removeValue(forKey: id) else { return }
            d.finished = true
            let cancelled = f.count > 1 && f[1] == "cancelled"
            let resume = d.resumeData
            // cancel(_:) gets the resume data; the delegate hears only of other failures
            if let c = d.cancelled { d.cancelled = nil; c(resume); return }
            let e: Error = cancelled ? URLError(.cancelled) : URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: f.count > 2 ? f[2] : "The download failed."])
            d.delegate?.download?(d, didFailWithError: e, resumeData: resume)
        default: break
        }
    }
}

extension WKWebView {
    /// downloads the request's URL with the web view's session (cookies, credentials)
    @objc(startDownloadUsingRequest:completionHandler:)
    open dynamic func startDownload(using request: URLRequest, completionHandler: @escaping (WKDownload) -> Void) {
        guard let u = request.url else { return }
        let req = _WKEngine.shared.newRequestID()
        _WKDownloads.starting[req] = completionHandler
        _send(["download", String(req), u.absoluteString])
    }
    public final func startDownload(using request: URLRequest) async -> WKDownload {
        await withCheckedContinuation { k in startDownload(using: request) { k.resume(returning: $0) } }
    }
    /// restarts a cancelled or failed download (WebKitGTK downloads it again, to the same destination)
    @objc(resumeDownloadFromResumeData:completionHandler:)
    open dynamic func resumeDownload(fromResumeData resumeData: Data, completionHandler: @escaping (WKDownload) -> Void) {
        guard let o = (try? PropertyListSerialization.propertyList(from: resumeData, options: [], format: nil)) as? [String: Any],
              let s = o["NSURLDownloadURL"] as? String, let u = URL(string: s) else {
            NSException(name: "NSInvalidArgumentException", reason: "Invalid resume data", userInfo: nil).raise()
        }
        let req = _WKEngine.shared.newRequestID()
        if let p = o["NSURLDownloadPath"] as? String { _WKDownloads.resumeDestinations[req] = URL(fileURLWithPath: p) }
        _WKDownloads.starting[req] = completionHandler
        _send(["download", String(req), u.absoluteString])
    }
    public final func resumeDownload(fromResumeData resumeData: Data) async -> WKDownload {
        await withCheckedContinuation { k in resumeDownload(fromResumeData: resumeData) { k.resume(returning: $0) } }
    }

    // MARK: authentication challenges

    /// the engine asks for credentials (HTTP Basic, Digest, NTLM...): the navigation delegate answers
    func _authEvent(_ f: [String]) {
        guard f.count >= 2 else { return }
        let req = f[0], o = _wkJSONObject(f[1])
        let page = URL(string: o["url"] as? String ?? "")
        let method: String
        switch o["scheme"] as? Int ?? 1 {
        case 2: method = NSURLAuthenticationMethodHTTPBasic
        case 3: method = NSURLAuthenticationMethodHTTPDigest
        case 4: method = NSURLAuthenticationMethodHTMLForm
        case 5: method = NSURLAuthenticationMethodNTLM
        case 6: method = NSURLAuthenticationMethodNegotiate
        default: method = NSURLAuthenticationMethodDefault
        }
        let host = o["host"] as? String ?? page?.host ?? "", port = o["port"] as? Int ?? 0, realm = o["realm"] as? String
        let space = (o["proxy"] as? Bool ?? false)
            ? URLProtectionSpace(proxyHost: host, port: port, type: NSURLProtectionSpaceHTTPProxy, realm: realm, authenticationMethod: method)
            : URLProtectionSpace(host: host, port: port, protocol: page?.scheme ?? "https", realm: realm, authenticationMethod: method)
        let user = o["user"] as? String ?? ""
        let proposed = user.isEmpty ? nil : URLCredential(user: user, password: "", persistence: .forSession)
        var answered = false
        let answer: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void = { [weak self] disp, cred in
            guard !answered else { return }
            answered = true
            switch disp {
            case .useCredential:
                guard let cred, let u = cred.user else { self?._send(["auth", req, "1"]); return }
                let per = cred.persistence == .permanent || cred.persistence == .synchronizable ? 2 : cred.persistence == .forSession ? 1 : 0
                self?._send(["auth", req, "0", u, cred.password ?? "", String(per)])
            case .cancelAuthenticationChallenge: self?._send(["auth", req, "2"])
            case .rejectProtectionSpace: self?._send(["auth", req, "3"])
            default: self?._send(["auth", req, "1"])
            }
        }
        let sender = _WKChallengeSender(answer)
        let failure = page.map { HTTPURLResponse(url: $0, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: [:]) } ?? nil
        let challenge = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: proposed, previousFailureCount: (o["retry"] as? Bool ?? false) ? 1 : 0,
                                                   failureResponse: failure, error: nil, sender: sender)
        if let d = navigationDelegate, _wkHas(d, "webView:didReceiveAuthenticationChallenge:completionHandler:") {
            d.webView?(self, didReceive: challenge, completionHandler: answer)
        } else if let d = navigationDelegate, _wkHas(d, "webView:respondToAuthenticationChallenge:asyncCompletionHandler:") {
            _wkAsyncCast(d).webView(self, asyncChallenge: challenge, completionHandler: answer)
        } else { answer(.performDefaultHandling, nil) }      // no credentials: the server's 401 page, as on iOS
    }

    // MARK: camera and microphone

    func _mediaEvent(_ f: [String]) {
        guard f.count >= 3 else { return }
        let req = f[0], type = WKMediaCaptureType(rawValue: Int(f[1]) ?? 0) ?? .camera
        let page = URL(string: f[2])
        let origin = WKSecurityOrigin(url: page), frame = WKFrameInfo(main: true, url: page, webView: self)
        var answered = false
        let answer: (Bool) -> Void = { [weak self] ok in
            guard !answered else { return }
            answered = true
            self?._send(["media", req, ok ? "1" : "0"])
        }
        let decide: (WKPermissionDecision) -> Void = { [weak self] d in
            switch d {
            case .grant: answer(true)
            case .deny: answer(false)
            default: self?._promptMediaCapture(type, host: page?.host ?? "this website", answer)
            }
        }
        if let u = uiDelegate, _wkHas(u, "webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:decisionHandler:") {
            u.webView?(self, requestMediaCapturePermissionFor: origin, initiatedByFrame: frame, type: type, decisionHandler: decide)
        } else if let u = uiDelegate, _wkHas(u, "webView:requestMediaCapturePermissionForOrigin:initiatedByFrame:type:asyncDecisionHandler:") {
            _wkAsyncCast(u).webView(self, asyncMedia: origin, initiatedByFrame: frame, type: type, decisionHandler: decide)
        } else { decide(.prompt) }
    }
    /// iOS's prompt: Allow “host” to use your camera? (Don’t Allow / Allow)
    func _promptMediaCapture(_ type: WKMediaCaptureType, host: String, _ answer: @escaping (Bool) -> Void) {
        let what = type == .camera ? "camera" : type == .microphone ? "microphone" : "camera and microphone"
        let alert = UIAlertController(title: "Allow “\(host)” to use your \(what)?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Don’t Allow", style: .default) { _ in answer(false) })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in answer(true) })
        var top = window?.rootViewController
        while let p = top?.presentedViewController { top = p }
        guard let top else { answer(false); return }
        top.present(alert, animated: true)
    }
}

/// answers a WKWebView challenge when the app calls its sender instead of the completion handler
final class _WKChallengeSender: NSObject, URLAuthenticationChallengeSender {
    let answer: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    init(_ a: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) { answer = a }
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) { answer(.useCredential, credential) }
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) { answer(.useCredential, nil) }
    func cancel(_ challenge: URLAuthenticationChallenge) { answer(.cancelAuthenticationChallenge, nil) }
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) { answer(.performDefaultHandling, nil) }
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) { answer(.rejectProtectionSpace, nil) }
}
