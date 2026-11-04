# Social

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (61 of 61, exact) · **Rows:** 2: 2 ✅ · **iOS:** 6.0+
<!-- /generated:header -->

**Area:** [Web, network & communication](../COVERAGE.md#web) · **Apple:** [Social](https://developer.apple.com/documentation/social) · **Issues:** [`area:web`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aweb)

## How isim implements it

- **Adapted:** the Share-extension compose sheet (`SLComposeServiceViewController`, `isim/frameworks/Social`). Like the Simulator, the device has no Twitter, Facebook, Sina Weibo, Tencent Weibo or LinkedIn account (Accounts is out of scope: deprecated in iOS 15), so `SLComposeViewController` is unavailable and `SLRequest` is sent unsigned. Rows: [Platform](Platform.md) (app extensions).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SLComposeViewController` (`isAvailable(forServiceType:)`, `init(forServiceType:)`, `serviceType`, `setInitialText`, `add` image / URL, `removeAllImages`, `removeAllURLs`, `completionHandler`), `SLComposeViewControllerResult`, `SLServiceTypeTwitter` / `Facebook` / `SinaWeibo` / `TencentWeibo` / `LinkedIn` | ✅ | ≤17 | adapted: no social accounts, as in the Simulator: `isAvailable` is false; presented anyway, the composer dismisses itself and reports `.cancelled` (logged). The setters work until it is presented. Tested (HelloSafari, tests/ui/test_safari_home.py::test_safari_settings_and_social; Objective-C in HelloServicesObjC) |
| `SLRequest` (`init(forServiceType:requestMethod:url:parameters:)`, `account`, `requestMethod`, `url`, `parameters`, `addMultipartData`, `preparedURLRequest()`, `perform(handler:)`), `SLRequestMethod`, `SLRequestHandler` | ✅ | ≤17 | adapted: `preparedURLRequest()` puts the parameters in the query (GET, DELETE) or a form or multipart body (POST, PUT); `perform(handler:)` sends it with `URLSession`, without an account to sign it (logged). `account` is kept (Accounts' `ACAccount` is out of scope). Swift gets `URLRequest` / `HTTPURLResponse` from Social's Swift overlay. Tested (HelloSafari, HelloServicesObjC) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
