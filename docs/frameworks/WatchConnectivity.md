# WatchConnectivity

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator with no paired watch simulator (`isim/frameworks/WatchConnectivity`).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/WatchConnectivity` (the framework is
  Objective-C).
- **Versus Apple's Simulator:** the same: the session is supported and activates; nothing is paired, installed or
  reachable.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `WCSession` (`isSupported`, `default`, `delegate`, `activate()`, `activationState`, `isPaired`, `isWatchAppInstalled`, `isReachable`, `isComplicationEnabled`, `sendMessage`, `sendMessageData`, `applicationContext`, `updateApplicationContext(_:)`, `receivedApplicationContext`, `transferUserInfo`, `transferCurrentComplicationUserInfo`, `transferFile`, the outstanding transfers), `WCSessionDelegate`, `WCSessionActivationState`, `WCSessionFile`, `WCSessionFileTransfer`, `WCSessionUserInfoTransfer`, `WCError` | 🧩 | ≤17 | stub: activation completes as activated; messages fail with `notReachable`, `updateApplicationContext` throws `deviceNotPaired`, and user-info and file transfers finish with `deviceNotPaired`. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
