# ExtensionFoundation

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [ExtensionFoundation](https://developer.apple.com/documentation/extensionfoundation) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** partial (`isim/swift/overlays/ExtensionFoundation`): the `AppExtension` and `AppExtensionConfiguration`
  protocols the frameworks' extension protocols refine (BackgroundAssets' `BADownloaderExtension`). An extension's
  `@main` type runs through its extension point's framework, which hosts it.
- **Objective-C / C interface:** Swift only, like Apple's.
- **Versus Apple's Simulator:** app-defined extension points (`AppExtensionPoint`) and hosting your own app
  extensions (`AppExtensionProcess`, `AppExtensionIdentity`) are not in isim yet.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `AppExtension` (`configuration`, `init()`, `main()`), `AppExtensionConfiguration` (`accept(connection:)`) | 🟡 | 16.0 | the protocols; an extension point isim hosts runs the extension (BackgroundAssets: test_background_assets); a bare `AppExtension` logs that isim has no host for it |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
