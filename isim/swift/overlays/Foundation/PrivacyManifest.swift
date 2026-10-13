// isim Foundation: the tracking domains of the app's privacy manifests (iOS 17). When a manifest says the bundle
// tracks (NSPrivacyTracking) and lists NSPrivacyTrackingDomains, requests to those domains (and their subdomains)
// fail until the user allows tracking with App Tracking Transparency, like on iOS. Adapted: URLSession requests
// only; the error is NSURLErrorCannotFindHost and isim logs why. Manifests of the app, its frameworks and resource
// bundles are read once per process.

enum _IsimTrackingDomains {
    static let domains: [String] = {
        var out: [String] = []
        let fm = FileManager.default
        let app = Bundle.main.bundlePath
        var dirs = [app]
        if let e = fm.enumerator(atPath: app) {
            while let rel = e.nextObject() as? String {
                if rel.hasSuffix(".framework") || rel.hasSuffix(".bundle") { dirs.append((app as NSString).appendingPathComponent(rel)) }
            }
        }
        for d in dirs {
            guard let data = fm.contents(atPath: (d as NSString).appendingPathComponent("PrivacyInfo.xcprivacy")),
                  let m = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  (m["NSPrivacyTracking"] as? Bool) == true, let list = m["NSPrivacyTrackingDomains"] as? [String] else { continue }
            out += list.map { $0.lowercased() }
        }
        return out
    }()
    /// the tracking domain a host belongs to, when tracking is not authorized (ATT status 3 = authorized)
    static func blocked(_ host: String?) -> String? {
        guard let host = host?.lowercased(), !domains.isEmpty,
              UserDefaults.standard.integer(forKey: "_ISIMTrackingAuthorizationStatus") != 3 else { return nil }
        return domains.first { host == $0 || host.hasSuffix("." + $0) }
    }
}
