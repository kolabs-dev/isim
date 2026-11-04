# IdentityDocumentServicesUI

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (29 of 29, exact) · **Rows:** 3: 3 ✅ · **iOS:** 26.0+
<!-- /generated:header -->

**Area:** [Identity & security](../COVERAGE.md#security) · **Apple:** [IdentityDocumentServicesUI](https://developer.apple.com/documentation/identitydocumentservicesui) · **Issues:** [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

## How isim implements it

- **Approach:** adapted, isim's own engine (`isim/swift/overlays/IdentityDocumentServicesUI`).
  - `IdentityDocumentWebPresentmentController.performRequests` shows isim's document sheet. The sheet lists the
    registered documents (IdentityDocumentServices' store) of the installed apps that have a provider extension and
    whose type the request asks for.
  - Choosing one loads that app's provider extension into the calling process, as with isim's other extensions; iOS runs
    it in its own process. Its extension point is `EXExtensionPointIdentifier`
    `com.apple.identity-document-services.document-provider-ui`, which is proposed because Apple does not document it.
  - The extension's `ISO18013MobileDocumentRequestScene` is shown in a sheet with its
    `ISO18013MobileDocumentRequestContext`. The response its `sendResponse` handler builds for the caller's raw request
    (from the controller's delegate) is what `performRequests` returns.
  - `cancel()`, the sheet's Cancel or swiping the provider's sheet away throw `IdentityDocumentPresentmentError.cancelled`.
  - `ISIM_IDENTITY_DOCUMENT` answers the document sheet without showing it: a document identifier, or `cancel`. The
    sheets themselves are driven like any UI (`tap`, ids `isim-iddoc-sheet`, `isim-iddoc-provider`).
- **Objective-C / C interface:** Swift only, like Apple's.
- **Versus Apple's Simulator:** isim presents documents from the provider apps installed on the device, end to end.
  isim calls the provider's `performRegistrationUpdates()` when it loads the extension.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `IdentityDocumentWebPresentmentController` (`performRequests(_:origin:)`, `delegate`, `presentationContextProvider`), `IdentityDocumentWebPresentmentControllerDelegate`, `IdentityDocumentPresentmentControllerPresentationContextProviding`, `IdentityDocumentPresentmentControlling`, `IdentityDocumentPresentationAnchor` | ✅ | 26.0 | adapted: isim's document sheet (the matching registered documents of the installed provider apps), then the provider's scene; https origins only; one presentment at a time (`requestInProgress`); `ISIM_IDENTITY_DOCUMENT` answers the sheet. Tested (HelloIDDocs, test_identity_document_presentment) |
| `IdentityDocumentProvider` (`body`, `performRegistrationUpdates()`), `IdentityDocumentRequestScene`, `IdentityDocumentRequestSceneBuilder` | ✅ | 26.0 | adapted: the provider extension runs in the presenting process; `performRegistrationUpdates()` is called when it is loaded. Tested (HelloIDDocs) |
| `ISO18013MobileDocumentRequestScene`, `ISO18013MobileDocumentRequestContext` (`request`, `requestingWebsiteOrigin`, `cancel()`, `sendResponse`) | ✅ | 26.0 | adapted: the scene's view in a sheet; `sendResponse` builds the response for the caller's raw request, `cancel()` ends with `cancelled`. Tested (HelloIDDocs) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
