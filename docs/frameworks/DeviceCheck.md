# DeviceCheck

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (32 of 32, exact) · **Rows:** 100% (1: 1 ✅) · **iOS:** 11.0+
<!-- /generated:header -->

**Area:** [Identity & security](../COVERAGE.md#security) · **Apple:** [DeviceCheck](https://developer.apple.com/documentation/devicecheck) · **Issues:** [`area:security`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Asecurity)

## How isim implements it

- **Adapted:** local, with no Apple servers: a local root certificate signs, and `isim devicecheck` plays Apple's server.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| DeviceCheck / App Attest (`DCDevice`, `DCAppAttestService`) | ✅ | ≤17 | adapted, local, no Apple servers (`ISIM_APP_ATTEST=0`: unsupported, like the Simulator). `generateToken`: an opaque token signed with the device data's key; `isim devicecheck validate\|query\|update TOKEN` plays Apple's DeviceCheck server (the two bits per device and app). App Attest in Apple's formats: keys in the simulated Secure Enclave, key id = SHA-256 of the public key, the attestation object (CBOR `apple-appattest`, authData with the app id hash, AAGUID `appattestdevelop` / `appattest` by the environment entitlement, COSE key; x5c certificate with the nonce extension 1.2.840.113635.100.8.2) and assertions (signature over the nonce, increasing counter); the chain ends at the device data's isim App Attest root (`isim appattest root`), not Apple's, so servers trusting Apple's root reject it; the receipt is a local placeholder. Tested: HelloAttest (verified with openssl) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
