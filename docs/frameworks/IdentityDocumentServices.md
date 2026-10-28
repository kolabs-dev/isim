# IdentityDocumentServices

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Identity & security](../COVERAGE.md#security) · **Apple:** [IdentityDocumentServices](https://developer.apple.com/documentation/identitydocumentservices) · **Issues:** [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

## How isim implements it

- **Approach:** adapted, isim's own engine (`isim/swift/overlays/IdentityDocumentServices`):
  - an identity document provider's registrations are kept per app in the device data
    (`Library/isim/IdentityDocuments/<bundle ID>.json`; `isim iddocs list`);
  - the presentment types are Apple's value types;
  - the request validator decodes ISO 18013-5 DeviceRequests (CBOR).
- **Objective-C / C interface:** Swift only, like Apple's.
- **Versus Apple's Simulator:** registrations work the same on any device; there is no Wallet to present documents from yet
  (IdentityDocumentServicesUI: #744).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `IdentityDocumentProviderRegistrationStore` (`status`, `registrations`, `addRegistration`, `removeRegistration(forDocumentIdentifier:)`, `Status`, `RegistrationError`), `IdentityDocumentRegistration`, `MobileDocumentRegistration` | ✅ | 26.0 | adapted: needs the `com.apple.developer.identity-document-services.document-provider.mobile-document-types` entitlement (`notAuthorized` without it, `invalidRequest` for a type it does not list); a registration past its `invalidationDate` is not listed; adding one with the same identifier replaces it. `status` and `registrations` are plain properties (proposed). Tested: test_identity_documents (HelloIDDocs) |
| `ISO18013MobileDocumentRequest` (+ `DocumentRequest`, `DocumentRequestSet`, `ElementInfo`, `PresentmentRequest`, `RequestAuthentication`), `ISO18013MobileDocumentResponse`, `IdentityDocumentWebPresentmentRequest` / `Response`, `IdentityDocumentWebPresentmentRawRequest`, `IdentityDocumentPresentmentError` | ✅ | 26.0 | Apple's value types. Tested: test_identity_documents |
| `IdentityDocumentWebPresentmentRawRequestValidator.validateISO18013MobileDocumentRequest(_:origin:)` | ✅ | 26.0 | adapted: decodes a CBOR DeviceRequest (also inside an ISO 18013-7 `{"deviceRequest": …}` map): each document request with its namespaces and elements (intent to retain), and the reader authentication's x5chain; https origins only. The reader authentication's signature is not verified (proposed: that needs the presentment's session transcript). Tested: test_identity_documents |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
