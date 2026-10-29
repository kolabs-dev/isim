# FileProviderUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (16 of 16, exact) · **Rows:** 4: 4 ✅ · **iOS:** 11.0+
<!-- /generated:header -->

**Area:** [App extensions & system integration](../COVERAGE.md#system) · **Apple:** [FileProviderUI](https://developer.apple.com/documentation/fileproviderui) · **Issues:** [`area:system`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asystem)

## How isim implements it

- **Approach:** adapted (`isim/swift/overlays/FileProviderUI`): a file provider app's UI extension
  (`com.apple.fileprovider-actionsui`). The document picker and browser list its `NSExtensionFileProviderActions` in
  the menu of the provider's items ([FileProvider](FileProvider.md)). For one of them, isim loads the extension into the
  picker's app, like its other extensions, and presents its `FPUIActionExtensionViewController` as a sheet after
  `prepare(forAction:itemIdentifiers:)`. When a domain the picker opens fails to sync with
  `NSFileProviderError.notAuthenticated`, the extension shows after `prepare(forError:)`, like iOS's sign-in sheet;
  the domain syncs again once it completes. `completeRequest()` and `cancelRequest(withError:)` dismiss it.
- **Objective-C / C interface:** `sdk-src/Frameworks/FileProviderUI/FileProviderUI.h` (`FPUIActionIdentifier`,
  `FPUIErrorDomain`, `FPUIExtensionErrorCode` for both languages; the classes, the overlay's, for Objective-C).
- **Versus Apple's Simulator:** the extension runs in the picker's app, not in a process of its own.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `FPUIActionExtensionViewController` (`extensionContext`, `prepare(forAction:itemIdentifiers:)`) | ✅ | ≤17 | adapted: presented from the picker's item menu. Tested: test_file_provider (HelloFileProvider's Share) |
| `FPUIActionExtensionContext` (`completeRequest()`, `cancelRequest(withError:)`, `domainIdentifier`) | ✅ | ≤17 | completing or cancelling dismisses the sheet. Tested: test_file_provider |
| `FPUIActionExtensionViewController.prepare(forError:)` | ✅ | ≤17 | adapted: shown when opening a domain fails with `notAuthenticated`; completing it syncs again. Tested: test_file_provider (sign in) |
| `FPUIActionIdentifier`, `FPUIErrorDomain`, `FPUIExtensionErrorCode` | ✅ | ≤17 | Apple's values. Tested: test_services_objc |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
