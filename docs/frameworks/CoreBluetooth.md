# CoreBluetooth

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 87.4% of Apple's iOS API (394 of 451, exact) · **Rows:** 5: 3 🧩 2 ❌ · **iOS:** 5.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Stub,** like the Simulator: managers report `.unsupported`.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/CoreBluetooth` over the overlay's classes; the
  delegates are Apple's protocols. A manager made from Objective-C calls its delegate on the main queue.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Core Bluetooth, central role (`CBCentralManager`, `CBPeripheral`, `CBService`, `CBCharacteristic`, `CBUUID`, `CBError`) | 🧩 | ≤17 | stub, like the Simulator: managers report `.unsupported` (`.unauthorized` without `NSBluetoothAlwaysUsageDescription`), scans log iOS's API MISUSE and find nothing. `CBPeer.identifier` stays the same for a peer. Tested (HelloSensors: test_sensors) |
| Peripheral role: `CBPeripheralManager` (services, advertising, `updateValue`, `respond(to:withResult:)`, L2CAP channels, connection latency, the delegate's methods, option and restore keys), `CBMutableService`, `CBMutableCharacteristic`, `CBAttributePermissions`, `CBDescriptor`, `CBMutableDescriptor` and the descriptor UUID strings, `CBATTRequest`, `CBCentral`, `CBL2CAPChannel`, `CBATTError` | 🧩 | ≤17 | stub, like the Simulator: the types work as values (a mutable service keeps its characteristics, which keep their descriptors and point back at it), but the manager stays `.unsupported`, so `add`, `startAdvertising` and `updateValue` log iOS's API MISUSE message and do nothing (`updateValue` returns false). `CBMutableDescriptor` logs a misuse for descriptors other than the user description and the format, like iOS. Tested (HelloSensors: test_sensors) |
| Objective-C interface: every class above under Apple's names and selectors, `CBCentralManagerDelegate`, `CBPeripheralDelegate`, `CBPeripheralManagerDelegate`, the option, advertisement and descriptor constants, `CBErrorDomain`, `CBATTErrorDomain` | 🧩 | ≤17 | stub, like the Swift API. Tested (HelloSensorsObjC: test_sensors_objc) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `CBATTError`, `CBMutableDescriptor` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `CBChannelSoundingProcedureResults`, `CBChannelSoundingSessionConfiguration` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
57 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`static var channelSounding: CBCentralManager.Feature`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/feature/channelsounding)
- [`func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]?)`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/registerforconnectionevents(options:))
- [`func centralManager(CBCentralManager, connectionEventDidOccur: CBConnectionEvent, for: CBPeripheral)`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/centralmanager(_:connectioneventdidoccur:for:))
- [`func centralManager(CBCentralManager, didDisconnectPeripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/centralmanager(_:diddisconnectperipheral:timestamp:isreconnecting:error:))
- [`func centralManager(CBCentralManager, didUpdateANCSAuthorizationFor: CBPeripheral)`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/centralmanager(_:didupdateancsauthorizationfor:))
- [`let CBCentralManagerOptionDeviceAccessForMedia: String`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanageroptiondeviceaccessformedia)
- [`let CBCentralManagerRestoredStatePeripheralsKey: String`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerrestoredstateperipheralskey)
- [`let CBCentralManagerRestoredStateScanOptionsKey: String`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerrestoredstatescanoptionskey)
- [`let CBCentralManagerRestoredStateScanServicesKey: String`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerrestoredstatescanserviceskey)
- [`let CBCentralManagerScanOptionSolicitedServiceUUIDsKey: String`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerscanoptionsolicitedserviceuuidskey)
- [`CBChannelSoundingProcedureResults`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingprocedureresults)
- [`var distance: Double`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingprocedureresults/distance)
- [`CBChannelSoundingSessionConfiguration`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingsessionconfiguration)
- [`init(role: CBChannelSoundingSessionConfiguration.Role)`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingsessionconfiguration/init(role:))
- [`CBChannelSoundingSessionConfiguration.Role`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingsessionconfiguration/role-swift.enum)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingsessionconfiguration/role-swift.enum/init(rawvalue:))
- [`case initiator`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingsessionconfiguration/role-swift.enum/initiator)
- [`var role: CBChannelSoundingSessionConfiguration.Role`](https://developer.apple.com/documentation/corebluetooth/cbchannelsoundingsessionconfiguration/role-swift.property)
- [`CBConnectionEvent`](https://developer.apple.com/documentation/corebluetooth/cbconnectionevent)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/corebluetooth/cbconnectionevent/init(rawvalue:))
- [`case peerConnected`](https://developer.apple.com/documentation/corebluetooth/cbconnectionevent/peerconnected)
- [`case peerDisconnected`](https://developer.apple.com/documentation/corebluetooth/cbconnectionevent/peerdisconnected)
- [`CBConnectionEventMatchingOption`](https://developer.apple.com/documentation/corebluetooth/cbconnectioneventmatchingoption)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/corebluetooth/cbconnectioneventmatchingoption/init(rawvalue:))
- [`static let peripheralUUIDs: CBConnectionEventMatchingOption`](https://developer.apple.com/documentation/corebluetooth/cbconnectioneventmatchingoption/peripheraluuids)
- [`static let serviceUUIDs: CBConnectionEventMatchingOption`](https://developer.apple.com/documentation/corebluetooth/cbconnectioneventmatchingoption/serviceuuids)
- [`let CBConnectPeripheralOptionEnableAutoReconnect: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionenableautoreconnect)
- [`let CBConnectPeripheralOptionEnableAutoReconnect: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionenableautoreconnect)
- [`let CBConnectPeripheralOptionEnableTransportBridgingKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionenabletransportbridgingkey)
- [`let CBConnectPeripheralOptionEnableTransportBridgingKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionenabletransportbridgingkey)
- [`let CBConnectPeripheralOptionNotifyOnConnectionKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionnotifyonconnectionkey)
- [`let CBConnectPeripheralOptionNotifyOnConnectionKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionnotifyonconnectionkey)
- [`let CBConnectPeripheralOptionNotifyOnNotificationKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionnotifyonnotificationkey)
- [`let CBConnectPeripheralOptionNotifyOnNotificationKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionnotifyonnotificationkey)
- [`let CBConnectPeripheralOptionNotifyOnNotificationKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionnotifyonnotificationkey)
- [`let CBConnectPeripheralOptionNotifyOnNotificationKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionnotifyonnotificationkey)
- [`let CBConnectPeripheralOptionRequiresANCS: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionrequiresancs)
- [`let CBConnectPeripheralOptionRequiresANCS: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionrequiresancs)
- [`let CBConnectPeripheralOptionStartDelayKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionstartdelaykey)
- [`let CBConnectPeripheralOptionStartDelayKey: String`](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionstartdelaykey)
- [`static var channelSoundingConfigurationFailed: CBError.Code`](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/channelsoundingconfigurationfailed)
- [`static var channelSoundingProcedureFailed: CBError.Code`](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/channelsoundingprocedurefailed)
- [`case channelSoundingConfigurationFailed`](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/code/channelsoundingconfigurationfailed)
- [`case channelSoundingConfigurationFailed`](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/code/channelsoundingconfigurationfailed)
- [`case channelSoundingProcedureFailed`](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/code/channelsoundingprocedurefailed)
- [`case channelSoundingProcedureFailed`](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/code/channelsoundingprocedurefailed)
- [`var ancsAuthorized: Bool`](https://developer.apple.com/documentation/corebluetooth/cbperipheral/ancsauthorized)
- [`func cancelChannelSoundingSession()`](https://developer.apple.com/documentation/corebluetooth/cbperipheral/cancelchannelsoundingsession())
- [`func startChannelSoundingSession(CBChannelSoundingSessionConfiguration)`](https://developer.apple.com/documentation/corebluetooth/cbperipheral/startchannelsoundingsession(_:))
- [`func peripheral(CBPeripheral, didCompleteChannelSoundingSession: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:didcompletechannelsoundingsession:))
- [`func peripheral(CBPeripheral, didDiscoverDescriptorsFor: CBCharacteristic, error: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:diddiscoverdescriptorsfor:error:))
- [`func peripheral(CBPeripheral, didDiscoverIncludedServicesFor: CBService, error: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:diddiscoverincludedservicesfor:error:))
- [`func peripheral(CBPeripheral, didModifyServices: [CBService])`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:didmodifyservices:))
- [`func peripheral(CBPeripheral, didReadRSSI: NSNumber, error: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:didreadrssi:error:))
- [`func peripheral(CBPeripheral, didReceive: CBChannelSoundingProcedureResults?, error: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:didreceive:error:))
- [`func peripheral(CBPeripheral, didUpdateNotificationStateFor: CBCharacteristic, error: (any Error)?)`](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/peripheral(_:didupdatenotificationstatefor:error:))
- [`let CBUUIDCharacteristicObservationScheduleString: String`](https://developer.apple.com/documentation/corebluetooth/cbuuidcharacteristicobservationschedulestring)

</details>
<!-- /generated:missing -->
