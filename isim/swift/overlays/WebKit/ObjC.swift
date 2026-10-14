// isim WebKit for Objective-C (sdk-src/Frameworks/WebKit, issue #200). The overlay's classes carry Apple's Objective-C
// names (@objc(WKWebView)...), and their members are `@objc dynamic` under Apple's selectors, so Objective-C apps and
// binary SDKs (Google Mobile Ads...) call them, subclass the classes (an Objective-C subclass has no Swift vtable: every
// overridable member is dispatched through objc_msgSend, or is final) and add categories. Members whose Swift
// signature cannot be represented in Objective-C (Result completions, option sets, Swift-only defaults) are final and
// reach Objective-C through these entry points.
import UIKit

extension WKWebViewConfiguration: @preconcurrency NSCopying {
    @objc(copyWithZone:) public func copy(with zone: NSZone? = nil) -> Any { copy() }
    @objc(mediaTypesRequiringUserActionForPlayback) var _objc_mediaTypes: UInt {
        get { mediaTypesRequiringUserActionForPlayback.rawValue }
        set { mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes(rawValue: newValue) }
    }
    @objc(dataDetectorTypes) var _objc_dataDetectors: UInt {
        get { dataDetectorTypes.rawValue } set { dataDetectorTypes = WKDataDetectorTypes(rawValue: newValue) }
    }
}

extension WKContentRuleListStore {
    @objc(storeWithURL:) class func _objc_store(_ url: URL) -> WKContentRuleListStore { WKContentRuleListStore(url: url) }
}

extension WKWebsiteDataStore {
    @objc(httpCookieStore) var _objc_cookieStore: WKHTTPCookieStore { httpCookieStore }
}

extension WKWebView {
    @objc(evaluateJavaScript:inFrame:inContentWorld:completionHandler:)
    func _objc_evaluate(_ js: String, frame: WKFrameInfo?, world: WKContentWorld, _ done: ((Any?, Error?) -> Void)?) {
        evaluateJavaScript(js, in: frame, in: world) { r in
            switch r { case .success(let v): done?(v, nil); case .failure(let e): done?(nil, e) }
        }
    }
    @objc(callAsyncJavaScript:arguments:inFrame:inContentWorld:completionHandler:)
    func _objc_callAsync(_ body: String, arguments: [String: Any]?, frame: WKFrameInfo?, world: WKContentWorld, _ done: ((Any?, Error?) -> Void)?) {
        callAsyncJavaScript(body, arguments: arguments ?? [:], in: frame, in: world) { r in
            switch r { case .success(let v): done?(v, nil); case .failure(let e): done?(nil, e) }
        }
    }
    @objc(createPDFWithConfiguration:completionHandler:) func _objc_pdf(_ c: WKPDFConfiguration?, _ done: @escaping (Data?, Error?) -> Void) {
        createPDF(configuration: c ?? WKPDFConfiguration()) { r in
            switch r { case .success(let d): done(d, nil); case .failure(let e): done(nil, e) }
        }
    }
    @objc(createWebArchiveDataWithCompletionHandler:) func _objc_archive(_ done: @escaping (Data?, Error?) -> Void) {
        createWebArchiveData { r in
            switch r { case .success(let d): done(d, nil); case .failure(let e): done(nil, e) }
        }
    }
    @objc(findString:withConfiguration:completionHandler:)
    func _objc_find(_ s: String, _ c: WKFindConfiguration?, _ done: @escaping (WKFindResult) -> Void) {
        find(s, configuration: c ?? WKFindConfiguration(), completionHandler: done)
    }
}
