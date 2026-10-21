# ExternalAccessory

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 36.5% of Apple's iOS API (31 of 85, exact) · **Rows:** 1: 1 🧩 · **iOS:** 3.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [ExternalAccessory](https://developer.apple.com/documentation/externalaccessory) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no MFi accessories (`isim/frameworks/ExternalAccessory`).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/ExternalAccessory` (the framework is
  Objective-C).
- **Versus Apple's Simulator:** the same.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `EAAccessoryManager` (`shared()`, `connectedAccessories`, `showBluetoothAccessoryPicker(withNameFilter:completion:)`, `registerForLocalNotifications()`), `EAAccessory`, `EAAccessoryDelegate`, `EASession`, the connect / disconnect notifications and keys, `EABluetoothAccessoryPickerError` | 🧩 | ≤17 | stub: no accessory is connected, `EASession` returns nil, and the picker completes with `resultNotFound`. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
54 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`EAAccessoryManager.AccessoryDidConnectMessage`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydidconnectmessage)
- [`var accessory: EAAccessory`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydidconnectmessage/accessory)
- [`init(accessory: EAAccessory, userSelected: Bool)`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydidconnectmessage/init(accessory:userselected:))
- [`var userSelected: Bool`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydidconnectmessage/userselected)
- [`EAAccessoryManager.AccessoryDidDisconnectMessage`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydiddisconnectmessage)
- [`var accessory: EAAccessory`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydiddisconnectmessage/accessory)
- [`init(accessory: EAAccessory)`](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/accessorydiddisconnectmessage/init(accessory:))
- [`EABluetoothAccessoryPickerError`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror)
- [`static var alreadyConnected: EABluetoothAccessoryPickerError.Code`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/alreadyconnected)
- [`EABluetoothAccessoryPickerError.Code`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/code)
- [`case alreadyConnected`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/code/alreadyconnected)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/code/init(rawvalue:))
- [`case resultCancelled`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/code/resultcancelled)
- [`case resultFailed`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/code/resultfailed)
- [`case resultNotFound`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/code/resultnotfound)
- [`static var errorDomain: String`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/errordomain)
- [`static var resultCancelled: EABluetoothAccessoryPickerError.Code`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/resultcancelled)
- [`static var resultFailed: EABluetoothAccessoryPickerError.Code`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/resultfailed)
- [`static var resultNotFound: EABluetoothAccessoryPickerError.Code`](https://developer.apple.com/documentation/externalaccessory/eabluetoothaccessorypickererror/resultnotfound)
- [`EAWiFiUnconfiguredAccessory`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory)
- [`var macAddress: String`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory/macaddress)
- [`var manufacturer: String`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory/manufacturer)
- [`var model: String`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory/model)
- [`var name: String`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory/name)
- [`var properties: EAWiFiUnconfiguredAccessoryProperties`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory/properties)
- [`var ssid: String`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessory/ssid)
- [`EAWiFiUnconfiguredAccessoryBrowser`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser)
- [`func configureAccessory(EAWiFiUnconfiguredAccessory, withConfigurationUIOn: UIViewController)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser/configureaccessory(_:withconfigurationuion:))
- [`var delegate: (any EAWiFiUnconfiguredAccessoryBrowserDelegate)?`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser/delegate)
- [`init(delegate: (any EAWiFiUnconfiguredAccessoryBrowserDelegate)?, queue: dispatch_queue_t?)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser/init(delegate:queue:))
- [`func startSearchingForUnconfiguredAccessories(matching: NSPredicate?)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser/startsearchingforunconfiguredaccessories(matching:))
- [`func stopSearchingForUnconfiguredAccessories()`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser/stopsearchingforunconfiguredaccessories())
- [`var unconfiguredAccessories: Set<EAWiFiUnconfiguredAccessory>`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowser/unconfiguredaccessories)
- [`EAWiFiUnconfiguredAccessoryBrowserDelegate`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserdelegate)
- [`func accessoryBrowser(EAWiFiUnconfiguredAccessoryBrowser, didFindUnconfiguredAccessories: Set<EAWiFiUnconfiguredAccessory>)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserdelegate/accessorybrowser(_:didfindunconfiguredaccessories:))
- [`func accessoryBrowser(EAWiFiUnconfiguredAccessoryBrowser, didFinishConfiguringAccessory: EAWiFiUnconfiguredAccessory, with: EAWiFiUnconfiguredAccessoryConfigurationStatus)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserdelegate/accessorybrowser(_:didfinishconfiguringaccessory:with:))
- [`func accessoryBrowser(EAWiFiUnconfiguredAccessoryBrowser, didRemoveUnconfiguredAccessories: Set<EAWiFiUnconfiguredAccessory>)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserdelegate/accessorybrowser(_:didremoveunconfiguredaccessories:))
- [`func accessoryBrowser(EAWiFiUnconfiguredAccessoryBrowser, didUpdate: EAWiFiUnconfiguredAccessoryBrowserState)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserdelegate/accessorybrowser(_:didupdate:))
- [`EAWiFiUnconfiguredAccessoryBrowserState`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserstate)
- [`case configuring`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserstate/configuring)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserstate/init(rawvalue:))
- [`case searching`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserstate/searching)
- [`case stopped`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserstate/stopped)
- [`case wiFiUnavailable`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessorybrowserstate/wifiunavailable)
- [`EAWiFiUnconfiguredAccessoryConfigurationStatus`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryconfigurationstatus)
- [`case failed`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryconfigurationstatus/failed)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryconfigurationstatus/init(rawvalue:))
- [`case success`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryconfigurationstatus/success)
- [`case userCancelledConfiguration`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryconfigurationstatus/usercancelledconfiguration)
- [`EAWiFiUnconfiguredAccessoryProperties`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryproperties)
- [`init(rawValue: UInt)`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryproperties/init(rawvalue:))
- [`static var propertySupportsAirPlay: EAWiFiUnconfiguredAccessoryProperties`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryproperties/propertysupportsairplay)
- [`static var propertySupportsAirPrint: EAWiFiUnconfiguredAccessoryProperties`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryproperties/propertysupportsairprint)
- [`static var propertySupportsHomeKit: EAWiFiUnconfiguredAccessoryProperties`](https://developer.apple.com/documentation/externalaccessory/eawifiunconfiguredaccessoryproperties/propertysupportshomekit)

</details>
<!-- /generated:missing -->
