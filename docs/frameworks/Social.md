# Social

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 42.9% of Apple's iOS API (24 of 56, exact) · **iOS:** 6.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [Social](https://developer.apple.com/documentation/social) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Adapted:** the Share-extension compose sheet (`SLComposeServiceViewController`, `isim/frameworks/Social`); `SLComposeViewController` is unavailable. Rows: [Platform](Platform.md) (app extensions).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `SLComposeViewController`, `SLRequest` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
32 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`SLComposeViewController`](https://developer.apple.com/documentation/social/slcomposeviewcontroller)
- [`func add(UIImage!) -> Bool`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/add(_:)-1z68a)
- [`func add(URL!) -> Bool`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/add(_:)-3mn1w)
- [`var completionHandler: SLComposeViewControllerCompletionHandler!`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/completionhandler)
- [`init!(forServiceType: String!)`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/init(forservicetype:))
- [`class func isAvailable(forServiceType: String!) -> Bool`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/isavailable(forservicetype:))
- [`func removeAllImages() -> Bool`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/removeallimages())
- [`func removeAllURLs() -> Bool`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/removeallurls())
- [`var serviceType: String!`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/servicetype)
- [`func setInitialText(String!) -> Bool`](https://developer.apple.com/documentation/social/slcomposeviewcontroller/setinitialtext(_:))
- [`SLComposeViewControllerCompletionHandler`](https://developer.apple.com/documentation/social/slcomposeviewcontrollercompletionhandler)
- [`SLComposeViewControllerResult`](https://developer.apple.com/documentation/social/slcomposeviewcontrollerresult)
- [`case cancelled`](https://developer.apple.com/documentation/social/slcomposeviewcontrollerresult/cancelled)
- [`case done`](https://developer.apple.com/documentation/social/slcomposeviewcontrollerresult/done)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/social/slcomposeviewcontrollerresult/init(rawvalue:))
- [`SLRequest`](https://developer.apple.com/documentation/social/slrequest)
- [`var account: ACAccount!`](https://developer.apple.com/documentation/social/slrequest/account)
- [`func addMultipartData(Data!, withName: String!, type: String!, filename: String!)`](https://developer.apple.com/documentation/social/slrequest/addmultipartdata(_:withname:type:filename:))
- [`init!(forServiceType: String!, requestMethod: SLRequestMethod, url: URL!, parameters: [AnyHashable : Any]!)`](https://developer.apple.com/documentation/social/slrequest/init(forservicetype:requestmethod:url:parameters:)-2cnf1)
- [`init!(forServiceType: String!, requestMethod: SLRequestMethod, URL: URL!, parameters: [AnyHashable : Any]!)`](https://developer.apple.com/documentation/social/slrequest/init(forservicetype:requestmethod:url:parameters:)-92b1d)
- [`var parameters: [AnyHashable : Any]!`](https://developer.apple.com/documentation/social/slrequest/parameters)
- [`func perform(handler: SLRequestHandler!)`](https://developer.apple.com/documentation/social/slrequest/perform(handler:))
- [`func preparedURLRequest() -> URLRequest!`](https://developer.apple.com/documentation/social/slrequest/preparedurlrequest())
- [`var requestMethod: SLRequestMethod`](https://developer.apple.com/documentation/social/slrequest/requestmethod)
- [`var url: URL!`](https://developer.apple.com/documentation/social/slrequest/url)
- [`SLRequestHandler`](https://developer.apple.com/documentation/social/slrequesthandler)
- [`SLRequestMethod`](https://developer.apple.com/documentation/social/slrequestmethod)
- [`case DELETE`](https://developer.apple.com/documentation/social/slrequestmethod/delete)
- [`case GET`](https://developer.apple.com/documentation/social/slrequestmethod/get)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/social/slrequestmethod/init(rawvalue:))
- [`case POST`](https://developer.apple.com/documentation/social/slrequestmethod/post)
- [`case PUT`](https://developer.apple.com/documentation/social/slrequestmethod/put)

</details>
<!-- /generated:missing -->
