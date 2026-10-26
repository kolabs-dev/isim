# NearbyInteraction

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 51.4% of Apple's iOS API (89 of 173, exact) · **Rows:** 1: 1 🧩 · **iOS:** 14.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [NearbyInteraction](https://developer.apple.com/documentation/nearbyinteraction) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no Ultra Wideband (`isim/swift/overlays/NearbyInteraction`).
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/NearbyInteraction` over the overlay's classes;
  `NINearbyObject.direction` (a simd vector) is Swift-only.
- **Versus Apple's Simulator:** the same.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `NISession` (`deviceCapabilities`, `isSupported`, `delegate`, `delegateQueue`, `discoveryToken`, `configuration`, `run(_:)`, `pause()`, `invalidate()`), `NIDeviceCapability`, `NISessionDelegate`, `NIConfiguration`, `NINearbyPeerConfiguration`, `NINearbyAccessoryConfiguration`, `NIDiscoveryToken`, `NINearbyObject`, `NIError` | 🧩 | ≤17 | stub: no capabilities and no discovery token; running a configuration invalidates the session with `unsupportedPlatform`. Not yet: `setARSession(_:)`, `worldTransform(for:)`, algorithm convergence, DL-TDOA. Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
84 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`NIAlgorithmConvergence`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergence)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergence/init(coder:))
- [`var status: NIAlgorithmConvergenceStatus`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergence/status-654t)
- [`NIAlgorithmConvergenceStatus`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve)
- [`NIAlgorithmConvergenceStatus`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve)
- [`static func == (NIAlgorithmConvergenceStatus, NIAlgorithmConvergenceStatus) -> Bool`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/==(_:_:))
- [`static func == (NIAlgorithmConvergenceStatus, NIAlgorithmConvergenceStatus) -> Bool`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/==(_:_:))
- [`case converged`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/converged)
- [`case converged`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/converged)
- [`case notConverged([NIAlgorithmConvergenceStatus.Reason])`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/notconverged(_:))
- [`case notConverged([NIAlgorithmConvergenceStatus.Reason])`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/notconverged(_:))
- [`NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason)
- [`NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason)
- [`NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason)
- [`static let insufficientHorizontalSweep: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficienthorizontalsweep)
- [`static let insufficientHorizontalSweep: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficienthorizontalsweep)
- [`static let insufficientHorizontalSweep: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficienthorizontalsweep)
- [`static let insufficientLighting: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientlighting)
- [`static let insufficientLighting: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientlighting)
- [`static let insufficientLighting: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientlighting)
- [`static let insufficientMovement: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientmovement)
- [`static let insufficientMovement: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientmovement)
- [`static let insufficientMovement: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientmovement)
- [`static let insufficientSignalStrength: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientsignalstrength)
- [`static let insufficientSignalStrength: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientsignalstrength)
- [`static let insufficientSignalStrength: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientsignalstrength)
- [`static let insufficientVerticalSweep: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientverticalsweep)
- [`static let insufficientVerticalSweep: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientverticalsweep)
- [`static let insufficientVerticalSweep: NIAlgorithmConvergenceStatus.Reason`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/insufficientverticalsweep)
- [`var localizedDescription: String?`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/localizeddescription)
- [`var localizedDescription: String?`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/localizeddescription)
- [`var localizedDescription: String?`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/reason/localizeddescription)
- [`case unknown`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/unknown)
- [`case unknown`](https://developer.apple.com/documentation/nearbyinteraction/nialgorithmconvergencestatus-2fnve/unknown)
- [`var supportsBluetoothChannelSounding: Bool`](https://developer.apple.com/documentation/nearbyinteraction/nidevicecapability/supportsbluetoothchannelsounding)
- [`var supportsDLTDOAMeasurement: Bool`](https://developer.apple.com/documentation/nearbyinteraction/nidevicecapability/supportsdltdoameasurement)
- [`var deviceCapabilities: any NIDeviceCapability`](https://developer.apple.com/documentation/nearbyinteraction/nidiscoverytoken/devicecapabilities)
- [`NIDLTDOAConfiguration`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration)
- [`NIDLTDOAConfiguration.DiscoveryMethod`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/discoverymethod-swift.enum)
- [`case bluetoothLowEnergy`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/discoverymethod-swift.enum/bluetoothlowenergy)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/discoverymethod-swift.enum/init(rawvalue:))
- [`case wifi`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/discoverymethod-swift.enum/wifi)
- [`var discoveryMethod: NIDLTDOAConfiguration.DiscoveryMethod`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/discoverymethod-swift.property)
- [`init(networkIdentifier: Int)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/init(networkidentifier:))
- [`init(networkIdentifier: Int, discoveryMethod: NIDLTDOAConfiguration.DiscoveryMethod)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/init(networkidentifier:discoverymethod:))
- [`var networkIdentifier: Int`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoaconfiguration/networkidentifier)
- [`NIDLTDOACoordinatesType`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoacoordinatestype)
- [`case geodetic`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoacoordinatestype/geodetic)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoacoordinatestype/init(rawvalue:))
- [`case relative`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoacoordinatestype/relative)
- [`NIDLTDOAMeasurement`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement)
- [`var address: Int`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/address)
- [`var carrierFrequencyOffset: Double`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/carrierfrequencyoffset)
- [`var clusterInitiatorAddress: Int`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/clusterinitiatoraddress)
- [`var coordinates: simd_double3`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/coordinates)
- [`var coordinatesType: NIDLTDOACoordinatesType`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/coordinatestype)
- [`NIDLTDOAMeasurement.FloorElevation`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/floorelevation-swift.class)
- [`var floorNumber: Int`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/floorelevation-swift.class/floornumber)
- [`var height: Double`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/floorelevation-swift.class/height)
- [`var floorElevation: NIDLTDOAMeasurement.FloorElevation?`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/floorelevation-swift.property)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/init(coder:))
- [`var measurementType: NIDLTDOAMeasurementType`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/measurementtype)
- [`var rawReceiveTime: UInt64`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/rawreceivetime)
- [`var rawTransmitTime: UInt64`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/rawtransmittime)
- [`var receiveTime: Double`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/receivetime)
- [`var responderClockFrequencyOffset: Double?`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/responderclockfrequencyoffset-8wu5r)
- [`var signalStrength: Double`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/signalstrength)
- [`var transmitTime: Double`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurement/transmittime)
- [`NIDLTDOAMeasurementType`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurementtype)
- [`case final`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurementtype/final)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurementtype/init(rawvalue:))
- [`case poll`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurementtype/poll)
- [`case response`](https://developer.apple.com/documentation/nearbyinteraction/nidltdoameasurementtype/response)
- [`NIMotionActivityState`](https://developer.apple.com/documentation/nearbyinteraction/nimotionactivitystate)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/nearbyinteraction/nimotionactivitystate/init(rawvalue:))
- [`case moving`](https://developer.apple.com/documentation/nearbyinteraction/nimotionactivitystate/moving)
- [`case stationary`](https://developer.apple.com/documentation/nearbyinteraction/nimotionactivitystate/stationary)
- [`case unknown`](https://developer.apple.com/documentation/nearbyinteraction/nimotionactivitystate/unknown)
- [`var horizontalAngle: Float?`](https://developer.apple.com/documentation/nearbyinteraction/ninearbyobject/horizontalangle-hsg)
- [`func setARSession(ARSession)`](https://developer.apple.com/documentation/nearbyinteraction/nisession/setarsession(_:))
- [`func updateMotionState(NIMotionActivityState, forObjectWithToken: NIDiscoveryToken)`](https://developer.apple.com/documentation/nearbyinteraction/nisession/updatemotionstate(_:forobjectwithtoken:))
- [`func worldTransform(for: NINearbyObject) -> simd_float4x4?`](https://developer.apple.com/documentation/nearbyinteraction/nisession/worldtransform(for:))
- [`func sessionDidStartRunning(NISession)`](https://developer.apple.com/documentation/nearbyinteraction/nisessiondelegate/sessiondidstartrunning(_:))

</details>
<!-- /generated:missing -->
