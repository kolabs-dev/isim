// isim Foundation: App Transport Security (adapted). The app's Info.plist NSAppTransportSecurity dictionary decides
// which loads may use cleartext HTTP and which TLS settings HTTPS needs, with iOS 10+'s rules:
//  - cleartext http:// and ws:// loads are refused (NSURLErrorAppTransportSecurityRequiresSecureConnection) unless an
//    exception allows them: NSAllowsArbitraryLoads, NSAllowsArbitraryLoadsInWebContent (WKWebView),
//    NSAllowsArbitraryLoadsForMedia (AVFoundation), NSAllowsLocalNetworking (unqualified names and .local), or an
//    NSExceptionDomains entry with NSExceptionAllowsInsecureHTTPLoads;
//  - IP-address literals are not subject to ATS;
//  - any of the InWebContent / ForMedia / LocalNetworking keys makes NSAllowsArbitraryLoads ignored;
//  - an NSExceptionDomains entry replaces the global settings for its domain (NSIncludesSubdomains: and its
//    subdomains; the most specific entry wins), its keys defaulting to ATS's defaults;
//  - HTTPS needs TLS 1.2 or later with a forward-secrecy (ECDHE) cipher suite, unless the load is exempt;
//    NSExceptionMinimumTLSVersion and NSExceptionRequiresForwardSecrecy change that per domain.
// Only apps are subject to it (a bundle with an identifier); custom URLProtocols load what they like, as on iOS.
// Not enforced: NSRequiresCertificateTransparency (parsed; libcurl cannot check SCTs), subresources inside a web page.

struct _ATSPolicy {
    struct Exception {
        var includesSubdomains = false
        var allowsInsecureHTTP = false
        var minimumTLS: String? = nil
        var requiresForwardSecrecy = true
        var requiresCertificateTransparency = false
    }
    enum Loader { case session, webContent, media }

    var enforced = true
    var allowsArbitrary = false, allowsInWebContent = false, allowsForMedia = false, allowsLocal = false
    var exceptions: [String: Exception] = [:]

    static let main = _ATSPolicy(Bundle.main.bundleIdentifier == nil ? nil : Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity"),
                                 enforced: Bundle.main.bundleIdentifier != nil)

    init(_ plist: Any?, enforced: Bool = true) {
        self.enforced = enforced
        guard let d = plist as? [String: Any] else { return }
        func flag(_ o: [String: Any], _ k: String) -> Bool? { (o[k] as? Bool) ?? (o[k] as? NSNumber)?.boolValue }
        allowsInWebContent = flag(d, "NSAllowsArbitraryLoadsInWebContent") ?? false
        allowsForMedia = flag(d, "NSAllowsArbitraryLoadsForMedia") ?? false
        allowsLocal = flag(d, "NSAllowsLocalNetworking") ?? false
        let overridden = d["NSAllowsArbitraryLoadsInWebContent"] != nil || d["NSAllowsArbitraryLoadsForMedia"] != nil || d["NSAllowsLocalNetworking"] != nil
        allowsArbitrary = !overridden && (flag(d, "NSAllowsArbitraryLoads") ?? false)
        for (domain, v) in (d["NSExceptionDomains"] as? [String: Any]) ?? [:] {
            guard let o = v as? [String: Any] else { continue }
            var e = Exception()
            e.includesSubdomains = flag(o, "NSIncludesSubdomains") ?? false
            e.allowsInsecureHTTP = flag(o, "NSExceptionAllowsInsecureHTTPLoads") ?? flag(o, "NSThirdPartyExceptionAllowsInsecureHTTPLoads") ?? false
            e.minimumTLS = (o["NSExceptionMinimumTLSVersion"] ?? o["NSThirdPartyExceptionMinimumTLSVersion"]) as? String
            e.requiresForwardSecrecy = flag(o, "NSExceptionRequiresForwardSecrecy") ?? flag(o, "NSThirdPartyExceptionRequiresForwardSecrecy") ?? true
            e.requiresCertificateTransparency = flag(o, "NSRequiresCertificateTransparency") ?? false
            exceptions[domain.lowercased()] = e
        }
    }

    static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true }                       /* IPv6 */
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { !$0.isEmpty && $0.count <= 3 && $0.allSatisfy({ $0.isASCII && $0.isNumber }) && Int($0)! <= 255 }
    }
    static func isLocal(_ host: String) -> Bool { !host.contains(".") || host.hasSuffix(".local") }

    /// the NSExceptionDomains entry for host: an exact match, else the longest domain whose subdomains it includes
    func exception(for host: String) -> Exception? {
        if let e = exceptions[host] { return e }
        var best: (String, Exception)? = nil
        for (d, e) in exceptions where e.includesSubdomains && host.hasSuffix("." + d) && d.count > (best?.0.count ?? -1) { best = (d, e) }
        return best?.1
    }
    private static func host(_ url: URL) -> String {
        var h = (url.host ?? "").lowercased()
        if h.hasPrefix("[") && h.hasSuffix("]") { h = String(h.dropFirst().dropLast()) }
        if h.hasSuffix(".") { h.removeLast() }
        return h
    }

    /// whether a cleartext (http: / ws:) load of url is allowed
    func allowsCleartext(_ url: URL, loader: Loader = .session) -> Bool {
        let h = Self.host(url)
        if !enforced || h.isEmpty || Self.isIPAddress(h) { return true }
        if let e = exception(for: h) { return e.allowsInsecureHTTP }
        if allowsLocal && Self.isLocal(h) { return true }
        switch loader {
        case .webContent where allowsInWebContent: return true
        case .media where allowsForMedia: return true
        default: return allowsArbitrary
        }
    }

    /// TLS settings ATS requires for an HTTPS load of url: the minimum version as libcurl's CURL_SSLVERSION_* (0: any)
    /// and whether only forward-secrecy cipher suites may be used
    func tlsRequirements(_ url: URL, loader: Loader = .session) -> (minimum: Int32, forwardSecrecy: Bool) {
        let h = Self.host(url)
        if !enforced || h.isEmpty || Self.isIPAddress(h) { return (0, false) }
        if let e = exception(for: h) { return (Self.curlVersion(e.minimumTLS ?? "TLSv1.2"), e.requiresForwardSecrecy) }
        if allowsLocal && Self.isLocal(h) { return (0, false) }
        switch loader {
        case .webContent where allowsInWebContent, .media where allowsForMedia: return (0, false)
        default: return allowsArbitrary ? (0, false) : (6, true)
        }
    }
    static func curlVersion(_ s: String) -> Int32 {
        switch s.uppercased() {
        case "TLSV1.0": return 4
        case "TLSV1.1": return 5
        case "TLSV1.3": return 7
        default: return 6                                           /* TLSv1.2, and unknown values */
        }
    }

    /// the error iOS reports for a blocked cleartext load, after logging the console message iOS logs
    static func blockedError(_ url: URL) -> URLError {
        FileHandle.standardError.write(Data("App Transport Security has blocked a cleartext HTTP (http://) resource load since it is insecure. Use HTTPS instead or add Exception Domains to your app's Info.plist. (\(url.absoluteString))\n".utf8))
        return URLError(.appTransportSecurityRequiresSecureConnection, userInfo: [
            NSLocalizedDescriptionKey: "The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.",
            NSURLErrorFailingURLErrorKey: url, NSURLErrorFailingURLStringErrorKey: url.absoluteString])
    }
}

/// isim (WebKit): the App Transport Security error for a web view navigation to url, or nil when ATS allows it
public func _isimATSWebContentError(_ url: URL) -> Error? {
    guard let s = url.scheme?.lowercased(), s == "http" || s == "ws" else { return nil }
    return _ATSPolicy.main.allowsCleartext(url, loader: .webContent) ? nil : _ATSPolicy.blockedError(url)
}
