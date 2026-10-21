# CFNetwork

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Foundation & CoreFoundation](../COVERAGE.md#foundation) · **Apple:** [CFNetwork](https://developer.apple.com/documentation/cfnetwork) · **Issues:** [`area:foundation`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Afoundation)

## How isim implements it

- **Adapted:** a small C framework (`isim/frameworks/CFNetwork`). CFHost resolves names and addresses through the
  host's resolver (getaddrinfo / getnameinfo in libSystem, Darwin socket addresses); its reachability is
  SystemConfiguration's. URL loading is Foundation's `URLSession`, as on iOS.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/CFNetwork` (`CFNetwork.h`, `CFHost.h`,
  `CFNetworkErrors.h`); `CFStreamError` is in CoreFoundation's `CFStream.h`.
- **Versus Apple's Simulator:** a name resolves as the Linux host resolves it (its DNS, `/etc/hosts`).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CFHost` (`CFHostCreateWithName`, `…WithAddress`, `…Copy`, `CFHostStartInfoResolution` for addresses, names and reachability, `CFHostGetAddressing` / `GetNames` / `GetReachability`, `CFHostCancelInfoResolution`, `CFHostSetClient`, `CFHostScheduleWithRunLoop` / `Unschedule…`, `CFHostGetTypeID`), `kCFStreamErrorDomainNetDB`, `kCFErrorDomainCFNetwork`, `CFNetworkErrors` (host codes), `kCFGetAddrInfoFailureKey` | ✅ | ≤17 | adapted: without a client the resolution finishes before `CFHostStartInfoResolution` returns; with one it runs on a background queue and the client is called on the run loops the host is scheduled on. Errors are getaddrinfo's `EAI_*` in `kCFStreamErrorDomainNetDB`. Tested (HelloSystemObjC, test_system_objc; test_binary_sdk_link: Google Mobile Ads 12.14 links, #606) |
| `CFHTTPMessage`, `CFHTTPAuthentication`, `CFNetServices`, `CFProxySupport` (`CFNetworkCopySystemProxySettings`, …), the socket streams (`CFStreamCreatePairWithSocketToHost`) | ❌ | ≤17 | not in isim yet: Foundation's `URLSession` and `Stream`, and Network's `NWBrowser` / `nw_browser` for Bonjour, cover most of the same ground |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
