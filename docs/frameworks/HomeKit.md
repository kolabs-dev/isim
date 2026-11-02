# HomeKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 99.9% of Apple's iOS API (3655 of 3660, exact) · **Rows:** 16: 6 ✅ 5 🟡 4 🧩 1 ❌ · **iOS:** 8.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [HomeKit](https://developer.apple.com/documentation/homekit) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Decided (issue #416): simulated homes.** isim has no home hub and no accessories. The device keeps its homes in
  `ISIM_DATA/Library/isim/HomeKit/homes.json`, shared by every app like iOS's home data.
  - `isim home seed` makes an example home with a home hub, rooms, a zone, eight accessories and two accessories
    nearby. The accessories are a color light, a thermostat, a lock, a garage door, an outlet, a motion sensor with a
    battery, blinds and a camera doorbell.
  - `isim home set|reachable|add-accessory|list|clear` change it from outside, as accessories would
    ([SCRIPTING.md](../SCRIPTING.md)).
  - Running apps notice changes within half a second and get their delegate callbacks. Like iOS, an app's own changes
    go to its completion handlers, not its delegates.
- **The simulated accessories behave like real ones** (`isim/swift/overlays/HomeKit/Store.swift`):
  - a lock's current state follows its target, and its last known action becomes "remotely";
  - a garage door goes through opening or closing for two seconds;
  - a thermostat's current mode and temperature follow their targets ("auto" heats or cools toward the target);
  - an outlet is in use while it is on, and blinds, fans, purifiers and TVs follow their targets.
- **Writes are checked as HomeKit checks them:** read-only and write-only characteristics, the value's type against
  the metadata's format, the minimum, maximum and valid values, and unreachable or blocked accessories.
- **Automations run in the app while it runs** (a home hub runs them on iOS):
  - timer triggers fire at their fire date and recurrence;
  - event triggers fire on characteristic and threshold events (with their predicate) and at calendar events;
  - significant time, location, presence and duration events are kept but never fire, because isim has no people or
    sun to watch.
- **Accessory setup:** `HMAccessoryBrowser` finds the accessories nearby. `HMAccessorySetupManager` and the deprecated
  `addAndSetupAccessories` show isim's "Add Accessory" sheet, or add the accessory a setup payload's `X-HM://` code
  names. `ISIM_HOMEKIT_ADD_ACCESSORY=NAME` answers the sheet ([SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)).
- **Cameras** have no video: a stream and a snapshot show a drawn picture with the camera's name and the time
  (`HMCameraView`, `CameraView`).
- **Access** needs the `com.apple.developer.homekit` entitlement (else `HMError.missingEntitlement`) and
  `NSHomeKitUsageDescription`. The first `HMHomeManager` asks with isim's "Would Like to Access Your Home Data" alert
  (`ISIM_HOMEKIT_PERMISSION=allow|deny` answers it). Denied apps see no homes, and changes fail with
  `homeAccessNotAuthorized`.
- **Type identifiers** are HAP's (the HomeKit Accessory Protocol's), generated with the characteristic value enums and
  `HMError`'s codes by `isim/tools/homekit-types.py`. The accessory category identifiers are isim's, because Apple's are
  private.
- **Objective-C / C interface:** `sdk-src/Frameworks/HomeKit`. The classes are the Swift overlay's with Apple's names and
  selectors. The generic `HMCharacteristicWriteAction` and `HMCharacteristicEvent` are HomeKit.framework's own
  (`frameworks/HomeKit/HomeKit.m`), because Swift generics cannot be exported to Objective-C.
- **Versus a device:** no real accessories, Matter or Thread, no other people in the home, no home hub (automations
  stop with the app), and no Home app.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `HMHomeManager` (`homes`, `primaryHome`, `authorizationStatus`, `addHome`, `removeHome`, `updatePrimaryHome`), `HMHomeManagerDelegate`, `HMHomeManagerAuthorizationStatus` | 🟡 | ≤17 | adapted: the device's simulated homes and isim's access prompt (allowed and denied tested). Tested (HelloHome, test_homekit) |
| `HMHome`: rooms, zones, service groups, accessories (add, remove, assign to a room, unblock), action sets, triggers, users (`currentUser`, `manageUsers`, `homeAccessControl(for:)`), `homeHubState`, `roomForEntireHome()`, `servicesWithTypes`, `HMHomeDelegate` | ✅ | ≤17 | adapted: name checks like HomeKit's (taken names, invalid characters). Tested (rooms, zones, groups, the delegate for outside changes) |
| `HMRoom`, `HMZone`, `HMServiceGroup`, `HMUser`, `HMAccessControl`, `HMHomeAccessControl` | ✅ | ≤17 | tested |
| `HMAccessory` (services, profiles, category, reachability, bridged accessories, `identify`, `updateName`), `HMAccessoryDelegate`, `HMAccessoryCategory`, `HMAccessoryProfile` | ✅ | ≤17 | adapted: the simulated accessories; `isim home reachable` changes reachability (tested) |
| `HMService`, `HMCharacteristic` (read, write, notifications, `updateAuthorizationData`), `HMCharacteristicMetadata` | ✅ | ≤17 | adapted: writes checked against the metadata (too high, wrong type, read-only tested); notifications from the simulated accessories and `isim home set` (tested) |
| The service, characteristic and category type constants, the characteristic value enums (`HMCharacteristicValue…`), the metadata formats and units, the characteristic properties, `HMError` | ✅ | ≤17 | HAP's type identifiers; isim's category identifiers |
| `HMActionSet`, `HMAction`, `HMCharacteristicWriteAction`, built-in action sets | ✅ | ≤17 | run against the simulated accessories (tested, also from Objective-C) |
| `HMTrigger`, `HMTimerTrigger`, `HMEventTrigger` (with its predicates), `HMEvent`, `HMCharacteristicEvent`, `HMCharacteristicThresholdRangeEvent`, `HMCalendarEvent`, `HMNumberRange` and the mutable events | 🟡 | ≤17 | adapted: run in the app while it runs (a characteristic event's automation tested, also from Objective-C); predicates are isim's formats |
| `HMSignificantTimeEvent`, `HMDurationEvent`, `HMLocationEvent`, `HMPresenceEvent` and their mutable versions, `HMSignificantEvent`, `HMPresenceEventType`, `HMPresenceEventUserType` | 🧩 | ≤17 | stub: kept, never fire |
| `HMAccessoryBrowser`, `HMAccessorySetupManager`, `HMAccessorySetupRequest`, `HMAccessorySetupResult`, `HMAccessorySetupPayload`, `HMAccessoryOwnershipToken`, `addAndSetupAccessories` | 🟡 | ≤17 | adapted: the accessories nearby (`isim home add-accessory`); isim's Add Accessory sheet (tested: the browser, a setup code) |
| `HMAddAccessoryRequest` | 🧩 | ≤17 | stub: isim's simulated accessories have no manufacturer app that asks |
| `HMCameraProfile`, `HMCameraStreamControl`, `HMCameraSnapshotControl`, `HMCameraSettingsControl`, `HMCameraAudioControl`, `HMCameraStream`, `HMCameraSnapshot`, `HMCameraSource`, `HMCameraView`, `CameraView` | 🟡 | ≤17 | adapted: a drawn picture, no video (stream and snapshot tested) |
| `HMNetworkConfigurationProfile` | 🧩 | ≤17 | stub: network access is never restricted |
| Provisional homes (`addProvisionalHome`, `transferProvisionalHome`, `isProvisionalHome`), `HMHomeManager.PairingIdentity` and `ProvisionalConfiguration`, `HMAccessory.ManufacturerFeature` and `showManufacturerExtension`, `findVendorAccessory`, `HMMediaSourceDisplayOrderProfile`, `bridgedAccessories`, `hapInstanceID` | 🟡 | 26.0 | adapted: provisional homes are kept like any other (no Thread network); accessories have no manufacturer extensions or vendor keys. Proposed (not tested); not version-gated (Apple's snapshot has no availability for them) |
| The Matter controller (`matterControllerID`, its XPC blocks), `matterNodeID`, `matterEndpointID` | 🧩 | 16.1 | stub: isim has no Matter (issue #416) |
| `HMAccessorySetupRequest.matterPayload` | ❌ | 15.4 | needs the Matter framework's `MTRSetupPayload` (blocked, issue #416) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
5 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var matterPayload: MTRSetupPayload?`](https://developer.apple.com/documentation/homekit/hmaccessorysetuprequest/matterpayload)
- [`HMErrorBlock`](https://developer.apple.com/documentation/homekit/hmerrorblock)
- [`var uniqueIdentifier: UUID`](https://developer.apple.com/documentation/homekit/hmservice/uniqueidentifier)
- [`var uniqueIdentifier: UUID`](https://developer.apple.com/documentation/homekit/hmservice/uniqueidentifier)
- [`var uniqueIdentifier: UUID`](https://developer.apple.com/documentation/homekit/hmservice/uniqueidentifier)

</details>
<!-- /generated:missing -->
