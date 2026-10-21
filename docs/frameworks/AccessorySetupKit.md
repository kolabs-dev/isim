# AccessorySetupKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 39.5% of Apple's iOS API (79 of 200, exact) · **Rows:** 1: 1 🧩 · **iOS:** 18.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no Bluetooth or Wi-Fi accessories nearby
  (`isim/frameworks/AccessorySetupKit`); the overlay (`isim/swift/overlays/AccessorySetupKit`) types
  `bluetoothServiceUUID` with CoreBluetooth's `CBUUID`.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/AccessorySetupKit` (the framework is
  Objective-C; `CBUUID` from Objective-C waits for CoreBluetooth's Objective-C interface, #315).
- **Versus Apple's Simulator:** the picker shows no sheet on isim; it completes at once.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `ASAccessorySession` (`activate(on:eventHandler:)`, `invalidate()`, `accessories`, `showPicker(for:completionHandler:)`, `removeAccessory`, `renameAccessory`), `ASAccessoryEvent`, `ASAccessoryEventType`, `ASPickerDisplayItem`, `ASDiscoveryDescriptor`, `ASAccessory`, `ASError` | 🧩 | 18.0 | stub: activating sends `.activated`; there are no accessories; the picker completes with `discoveryTimeout`; removing or renaming fails with `invalidRequest`. Not yet: migration items, `finishAuthorization` / `failAuthorization`, the iOS 26 additions. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
121 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`ASAccessory.AccessoryState`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate)
- [`ASAccessory.AccessoryState`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate)
- [`ASAccessory.AccessoryState`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate)
- [`case authorized`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/authorized)
- [`case authorized`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/authorized)
- [`case authorized`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/authorized)
- [`case awaitingAuthorization`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/awaitingauthorization)
- [`case awaitingAuthorization`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/awaitingauthorization)
- [`case awaitingAuthorization`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/awaitingauthorization)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/init(rawvalue:))
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/init(rawvalue:))
- [`case unauthorized`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/unauthorized)
- [`case unauthorized`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/unauthorized)
- [`case unauthorized`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/accessorystate/unauthorized)
- [`var bluetoothTransportBridgingIdentifier: Data?`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/bluetoothtransportbridgingidentifier)
- [`var bluetoothTransportBridgingIdentifier: Data?`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/bluetoothtransportbridgingidentifier)
- [`ASAccessory.RenameOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/renameoptions)
- [`ASAccessory.RenameOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/renameoptions)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/renameoptions/init(rawvalue:))
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/renameoptions/init(rawvalue:))
- [`static var ssid: ASAccessory.RenameOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/renameoptions/ssid)
- [`static var ssid: ASAccessory.RenameOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/renameoptions/ssid)
- [`ASAccessory.SupportOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/supportoptions)
- [`static var bluetoothHID: ASAccessory.SupportOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/supportoptions/bluetoothhid)
- [`static var bluetoothPairingLE: ASAccessory.SupportOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/supportoptions/bluetoothpairingle)
- [`static var bluetoothTransportBridging: ASAccessory.SupportOptions`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/supportoptions/bluetoothtransportbridging)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/supportoptions/init(rawvalue:))
- [`var wifiAwarePairedDeviceID: ASAccessory.WiFiAwarePairedDeviceID`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/wifiawarepaireddeviceid-swift.property)
- [`var wifiAwarePairedDeviceID: ASAccessory.WiFiAwarePairedDeviceID`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/wifiawarepaireddeviceid-swift.property)
- [`ASAccessory.WiFiAwarePairedDeviceID`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/wifiawarepaireddeviceid-swift.typealias)
- [`ASAccessory.WiFiAwarePairedDeviceID`](https://developer.apple.com/documentation/accessorysetupkit/asaccessory/wifiawarepaireddeviceid-swift.typealias)
- [`case accessoryDiscovered`](https://developer.apple.com/documentation/accessorysetupkit/asaccessoryeventtype/accessorydiscovered)
- [`case accessoryDiscovered`](https://developer.apple.com/documentation/accessorysetupkit/asaccessoryeventtype/accessorydiscovered)
- [`func failAuthorization(for: ASAccessory, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession/failauthorization(for:completionhandler:))
- [`func finishAuthorization(for: ASAccessory, settings: ASAccessorySettings, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession/finishauthorization(for:settings:completionhandler:))
- [`func finishPickerDiscovery(completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession/finishpickerdiscovery(completionhandler:))
- [`var pickerDisplaySettings: ASPickerDisplaySettings?`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession/pickerdisplaysettings)
- [`func updateAuthorization(for: ASAccessory, descriptor: ASDiscoveryDescriptor, completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession/updateauthorization(for:descriptor:completionhandler:))
- [`func updatePicker(showing: [ASDiscoveredDisplayItem], completionHandler: ((any Error)?) -> Void)`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysession/updatepicker(showing:completionhandler:))
- [`ASAccessorySettings`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysettings)
- [`var bluetoothTransportBridgingIdentifier: Data?`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysettings/bluetoothtransportbridgingidentifier)
- [`class var `default`: ASAccessorySettings`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysettings/default)
- [`var ssid: String?`](https://developer.apple.com/documentation/accessorysetupkit/asaccessorysettings/ssid)
- [`init(UInt16)`](https://developer.apple.com/documentation/accessorysetupkit/asbluetoothcompanyidentifier/init(_:))
- [`init(UInt16)`](https://developer.apple.com/documentation/accessorysetupkit/asbluetoothcompanyidentifier/init(_:))
- [`init(rawValue: UInt16)`](https://developer.apple.com/documentation/accessorysetupkit/asbluetoothcompanyidentifier/init(rawvalue:))
- [`init(rawValue: UInt16)`](https://developer.apple.com/documentation/accessorysetupkit/asbluetoothcompanyidentifier/init(rawvalue:))
- [`ASDiscoveredAccessory`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoveredaccessory)
- [`var bluetoothAdvertisementData: [AnyHashable : Any]?`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoveredaccessory/bluetoothadvertisementdata)
- [`var bluetoothRSSI: Int?`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoveredaccessory/bluetoothrssi-5a2gp)
- [`ASDiscoveredDisplayItem`](https://developer.apple.com/documentation/accessorysetupkit/asdiscovereddisplayitem)
- [`init(name: String, productImage: UIImage, accessory: ASDiscoveredAccessory)`](https://developer.apple.com/documentation/accessorysetupkit/asdiscovereddisplayitem/init(name:productimage:accessory:))
- [`var bluetoothNameSubstringCompareOptions: NSString.CompareOptions`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/bluetoothnamesubstringcompareoptions)
- [`ASDiscoveryDescriptor.Range`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/range)
- [`case `default``](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/range/default)
- [`case immediate`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/range/immediate)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/range/init(rawvalue:))
- [`var wifiAwareModelNameMatch: ASPropertyCompareString?`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawaremodelnamematch)
- [`var wifiAwareServiceName: String?`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawareservicename)
- [`ASDiscoveryDescriptor.WiFiAwareServiceRole`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawareservicerole-swift.enum)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawareservicerole-swift.enum/init(rawvalue:))
- [`case publisher`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawareservicerole-swift.enum/publisher)
- [`case subscriber`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawareservicerole-swift.enum/subscriber)
- [`var wifiAwareServiceRole: ASDiscoveryDescriptor.WiFiAwareServiceRole`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawareservicerole-swift.property)
- [`var wifiAwareVendorNameMatch: ASPropertyCompareString?`](https://developer.apple.com/documentation/accessorysetupkit/asdiscoverydescriptor/wifiawarevendornamematch)
- [`ASError`](https://developer.apple.com/documentation/accessorysetupkit/aserror)
- [`static var activationFailed: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/activationfailed)
- [`ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code)
- [`case activationFailed`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/activationfailed)
- [`case connectionFailed`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/connectionfailed)
- [`case discoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/discoverytimeout)
- [`case extensionNotFound`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/extensionnotfound)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/init(rawvalue:))
- [`case invalidated`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/invalidated)
- [`case invalidRequest`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/invalidrequest)
- [`case pickerAlreadyActive`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/pickeralreadyactive)
- [`case pickerRestricted`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/pickerrestricted)
- [`case success`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/success)
- [`case unknown`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/unknown)
- [`case userCancelled`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/usercancelled)
- [`case userRestricted`](https://developer.apple.com/documentation/accessorysetupkit/aserror/code/userrestricted)
- [`static var connectionFailed: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/connectionfailed)
- [`static var discoveryTimeout: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/discoverytimeout)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/accessorysetupkit/aserror/errordomain)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/accessorysetupkit/aserror/errordomain)
- [`static var extensionNotFound: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/extensionnotfound)
- [`static var invalidated: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/invalidated)
- [`static var invalidRequest: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/invalidrequest)
- [`static var pickerAlreadyActive: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/pickeralreadyactive)
- [`static var pickerRestricted: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/pickerrestricted)
- [`static var success: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/success)
- [`static var unknown: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/unknown)
- [`static var userCancelled: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/usercancelled)
- [`static var userRestricted: ASError.Code`](https://developer.apple.com/documentation/accessorysetupkit/aserror/userrestricted)
- [`ASMigrationDisplayItem`](https://developer.apple.com/documentation/accessorysetupkit/asmigrationdisplayitem)
- [`var hotspotSSID: String?`](https://developer.apple.com/documentation/accessorysetupkit/asmigrationdisplayitem/hotspotssid)
- [`var peripheralIdentifier: UUID?`](https://developer.apple.com/documentation/accessorysetupkit/asmigrationdisplayitem/peripheralidentifier)
- [`var wifiAwarePairedDeviceID: ASAccessory.WiFiAwarePairedDeviceID`](https://developer.apple.com/documentation/accessorysetupkit/asmigrationdisplayitem/wifiawarepaireddeviceid)
- [`static var confirmAuthorization: ASPickerDisplayItem.SetupOptions`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplayitem/setupoptions-swift.struct/confirmauthorization)
- [`static var finishInApp: ASPickerDisplayItem.SetupOptions`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplayitem/setupoptions-swift.struct/finishinapp)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplayitem/setupoptions-swift.struct/init(rawvalue:))
- [`static var rename: ASPickerDisplayItem.SetupOptions`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplayitem/setupoptions-swift.struct/rename)
- [`ASPickerDisplaySettings`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings)
- [`class var `default`: ASPickerDisplaySettings`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/default)
- [`class var `default`: ASPickerDisplaySettings`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/default)
- [`var discoveryTimeout: ASPickerDisplaySettings.DiscoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.property)
- [`ASPickerDisplaySettings.DiscoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.struct)
- [`init(rawValue: TimeInterval)`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.struct/init(rawvalue:))
- [`static let long: ASPickerDisplaySettings.DiscoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.struct/long)
- [`static let medium: ASPickerDisplaySettings.DiscoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.struct/medium)
- [`static let short: ASPickerDisplaySettings.DiscoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.struct/short)
- [`static let unbounded: ASPickerDisplaySettings.DiscoveryTimeout`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/discoverytimeout-swift.struct/unbounded)
- [`var options: ASPickerDisplaySettings.Options`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/options-swift.property)
- [`ASPickerDisplaySettings.Options`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/options-swift.struct)
- [`static var filterDiscoveryResults: ASPickerDisplaySettings.Options`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/options-swift.struct/filterdiscoveryresults)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/accessorysetupkit/aspickerdisplaysettings/options-swift.struct/init(rawvalue:))
- [`ASPropertyCompareString`](https://developer.apple.com/documentation/accessorysetupkit/aspropertycomparestring)
- [`var compareOptions: NSString.CompareOptions`](https://developer.apple.com/documentation/accessorysetupkit/aspropertycomparestring/compareoptions)
- [`init(string: String, compareOptions: NSString.CompareOptions)`](https://developer.apple.com/documentation/accessorysetupkit/aspropertycomparestring/init(string:compareoptions:))
- [`var string: String`](https://developer.apple.com/documentation/accessorysetupkit/aspropertycomparestring/string)

</details>
<!-- /generated:missing -->
