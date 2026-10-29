# CoreMotion

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 73.9% of Apple's iOS API (306 of 414, exact) · **Rows:** 6: 1 ✅ 2 🧩 3 ❌ · **iOS:** 4.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [CoreMotion](https://developer.apple.com/documentation/coremotion) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Adapted:** a device held upright at rest, with Simulator-style "unavailable" answers.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/CoreMotion` over the overlay's classes: the motion
  manager and its data, the pedometer, motion activity, the altimeter and headphone motion.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Core Motion (accelerometer, gyroscope, pedometer) | ✅ | ≤17 | adapted: a device held upright at rest (gravity (0,-1,0), no rotation) for accelerometer/gyro/magnetometer/device-motion push and pull updates; `ISIM_MOTION=unavailable` reports no sensors like the Simulator; pedometer, activity, altimeter unavailable (Simulator); shake stays a UIKit motion event. Tested (HelloSensors, iOS 17–27) |
| Objective-C interface: `CMPedometer` (`CMPedometerData`, `CMPedometerEvent`), `CMMotionActivityManager` (`CMMotionActivity`), `CMAltimeter` (`CMAltitudeData`), `CMHeadphoneMotionManager`, `CMAuthorizationStatus`, `CMError` | 🧩 | ≤17 | stub, like the Simulator (and the Swift API): unavailable; queries fail with `CMErrorMotionActivityNotAvailable` / `CMErrorNotAvailable`. Tested (HelloSensorsObjC: test_sensors_objc) |
| Sensors the Simulator lacks: `CMHeadphoneMotionManager` (connection status, `CMHeadphoneMotionManagerDelegate`), `CMBatchedSensorManager`, `CMSensorRecorder` (`CMSensorDataList`, `CMRecordedAccelerometerData`), absolute altitude (`CMAltimeter.startAbsoluteAltitudeUpdates`, `CMAbsoluteAltitudeData`), `CMWaterSubmersionManager` (`CMWaterSubmersionEvent`, `CMWaterSubmersionMeasurement`, `CMWaterTemperature`, the delegate) | 🧩 | ≤17 | stub, like the Simulator: no headphones connect (connection status updates start, the delegate hears nothing); batched sensors are unsupported (the handlers get `CMError.notAvailable`, the `accelerometerUpdates()` / `deviceMotionUpdates()` sequences throw it); the recorder records nothing (`accelerometerData(from:to:)` is nil); absolute altitude updates fail with `notAvailable`; the water submersion delegate gets `manager(_:errorOccurred:)` with `notAvailable`. Objective-C too. Tested (HelloSensors: test_sensors, HelloSensorsObjC: test_sensors_objc) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `CMAmbientPressureData`, `CMDyskineticSymptomResult`, `CMHighFrequencyHeartRateData`, `CMOdometerData`, `CMRecordedPressureData`, `CMTremorResult` (6 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `CMHeadphoneActivityManager` (1 type; with its members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `CMBodyIdentifiable`, `CMRecordedDeviceMotion` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
108 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`CMAmbientPressureData`](https://developer.apple.com/documentation/coremotion/cmambientpressuredata)
- [`var pressure: Measurement<UnitPressure>`](https://developer.apple.com/documentation/coremotion/cmambientpressuredata/pressure)
- [`var temperature: Measurement<UnitTemperature>`](https://developer.apple.com/documentation/coremotion/cmambientpressuredata/temperature)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmattitude/init(coder:))
- [`CMBodyIdentifiable`](https://developer.apple.com/documentation/coremotion/cmbodyidentifiable)
- [`CMBodyIdentifiable`](https://developer.apple.com/documentation/coremotion/cmbodyidentifiable)
- [`var headingAccuracy: Double`](https://developer.apple.com/documentation/coremotion/cmdevicemotion/headingaccuracy)
- [`case `default``](https://developer.apple.com/documentation/coremotion/cmdevicemotion/sensorlocation-swift.enum/default)
- [`case headphoneLeft`](https://developer.apple.com/documentation/coremotion/cmdevicemotion/sensorlocation-swift.enum/headphoneleft)
- [`case headphoneRight`](https://developer.apple.com/documentation/coremotion/cmdevicemotion/sensorlocation-swift.enum/headphoneright)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coremotion/cmdevicemotion/sensorlocation-swift.enum/init(rawvalue:))
- [`CMDyskineticSymptomResult`](https://developer.apple.com/documentation/coremotion/cmdyskineticsymptomresult)
- [`var endDate: Date`](https://developer.apple.com/documentation/coremotion/cmdyskineticsymptomresult/enddate)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmdyskineticsymptomresult/init(coder:))
- [`var percentLikely: Float`](https://developer.apple.com/documentation/coremotion/cmdyskineticsymptomresult/percentlikely)
- [`var percentUnlikely: Float`](https://developer.apple.com/documentation/coremotion/cmdyskineticsymptomresult/percentunlikely)
- [`var startDate: Date`](https://developer.apple.com/documentation/coremotion/cmdyskineticsymptomresult/startdate)
- [`init(rawValue: UInt32)`](https://developer.apple.com/documentation/coremotion/cmerror/init(rawvalue:))
- [`var rawValue: UInt32`](https://developer.apple.com/documentation/coremotion/cmerror/rawvalue)
- [`var CMErrorDeviceRequiresMovement: CMError`](https://developer.apple.com/documentation/coremotion/cmerrordevicerequiresmovement)
- [`var CMErrorInvalidAction: CMError`](https://developer.apple.com/documentation/coremotion/cmerrorinvalidaction)
- [`var CMErrorInvalidParameter: CMError`](https://developer.apple.com/documentation/coremotion/cmerrorinvalidparameter)
- [`var CMErrorMotionActivityNotAuthorized: CMError`](https://developer.apple.com/documentation/coremotion/cmerrormotionactivitynotauthorized)
- [`var CMErrorMotionActivityNotAvailable: CMError`](https://developer.apple.com/documentation/coremotion/cmerrormotionactivitynotavailable)
- [`var CMErrorMotionActivityNotEntitled: CMError`](https://developer.apple.com/documentation/coremotion/cmerrormotionactivitynotentitled)
- [`var CMErrorNilData: CMError`](https://developer.apple.com/documentation/coremotion/cmerrornildata)
- [`var CMErrorNotAuthorized: CMError`](https://developer.apple.com/documentation/coremotion/cmerrornotauthorized)
- [`var CMErrorNotAvailable: CMError`](https://developer.apple.com/documentation/coremotion/cmerrornotavailable)
- [`var CMErrorNotEntitled: CMError`](https://developer.apple.com/documentation/coremotion/cmerrornotentitled)
- [`var CMErrorNULL: CMError`](https://developer.apple.com/documentation/coremotion/cmerrornull)
- [`var CMErrorSize: CMError`](https://developer.apple.com/documentation/coremotion/cmerrorsize)
- [`var CMErrorTrueNorthNotAvailable: CMError`](https://developer.apple.com/documentation/coremotion/cmerrortruenorthnotavailable)
- [`var CMErrorUnknown: CMError`](https://developer.apple.com/documentation/coremotion/cmerrorunknown)
- [`CMHeadphoneActivityManager`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager)
- [`CMHeadphoneActivityManager.ActivityHandler`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/activityhandler)
- [`class func authorizationStatus() -> CMAuthorizationStatus`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/authorizationstatus())
- [`var isActivityActive: Bool`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/isactivityactive)
- [`var isActivityAvailable: Bool`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/isactivityavailable)
- [`var isStatusActive: Bool`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/isstatusactive)
- [`var isStatusAvailable: Bool`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/isstatusavailable)
- [`func startActivityUpdates(to: OperationQueue, withHandler: CMHeadphoneActivityManager.ActivityHandler)`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/startactivityupdates(to:withhandler:))
- [`func startStatusUpdates(to: OperationQueue, withHandler: CMHeadphoneActivityManager.StatusHandler)`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/startstatusupdates(to:withhandler:))
- [`CMHeadphoneActivityManager.Status`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/status)
- [`case connected`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/status/connected)
- [`case disconnected`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/status/disconnected)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/status/init(rawvalue:))
- [`CMHeadphoneActivityManager.StatusHandler`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/statushandler)
- [`func stopActivityUpdates()`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/stopactivityupdates())
- [`func stopStatusUpdates()`](https://developer.apple.com/documentation/coremotion/cmheadphoneactivitymanager/stopstatusupdates())
- [`CMHighFrequencyHeartRateData`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedata)
- [`var confidence: CMHighFrequencyHeartRateDataConfidence`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedata/confidence)
- [`var date: Date?`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedata/date)
- [`var heartRate: Double`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedata/heartrate)
- [`CMHighFrequencyHeartRateDataConfidence`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedataconfidence)
- [`case high`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedataconfidence/high)
- [`case highest`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedataconfidence/highest)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedataconfidence/init(rawvalue:))
- [`case low`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedataconfidence/low)
- [`case medium`](https://developer.apple.com/documentation/coremotion/cmhighfrequencyheartratedataconfidence/medium)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmlogitem/init(coder:))
- [`CMMotionActivityQueryHandler`](https://developer.apple.com/documentation/coremotion/cmmotionactivityqueryhandler)
- [`class var authorizationStatus: CMAuthorizationStatus`](https://developer.apple.com/documentation/coremotion/cmmotionmanager/authorizationstatus)
- [`var deviceMotionBody: (any CMBodyIdentifiable)?`](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionbody)
- [`var deviceMotionBody: (any CMBodyIdentifiable)?`](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionbody)
- [`CMOdometerData`](https://developer.apple.com/documentation/coremotion/cmodometerdata)
- [`var deltaAltitude: CLLocationDistance`](https://developer.apple.com/documentation/coremotion/cmodometerdata/deltaaltitude)
- [`var deltaDistance: CLLocationDistance`](https://developer.apple.com/documentation/coremotion/cmodometerdata/deltadistance)
- [`var deltaDistanceAccuracy: CLLocationAccuracy`](https://developer.apple.com/documentation/coremotion/cmodometerdata/deltadistanceaccuracy)
- [`var endDate: Date`](https://developer.apple.com/documentation/coremotion/cmodometerdata/enddate)
- [`var gpsDate: Date`](https://developer.apple.com/documentation/coremotion/cmodometerdata/gpsdate)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmodometerdata/init(coder:))
- [`var maxAbsSlope: Double?`](https://developer.apple.com/documentation/coremotion/cmodometerdata/maxabsslope-9mnfd)
- [`var originDevice: CMOdometerOriginDevice`](https://developer.apple.com/documentation/coremotion/cmodometerdata/origindevice)
- [`var slope: Double?`](https://developer.apple.com/documentation/coremotion/cmodometerdata/slope-9h3m4)
- [`var speed: CLLocationSpeed`](https://developer.apple.com/documentation/coremotion/cmodometerdata/speed)
- [`var speedAccuracy: CLLocationSpeedAccuracy`](https://developer.apple.com/documentation/coremotion/cmodometerdata/speedaccuracy)
- [`var startDate: Date`](https://developer.apple.com/documentation/coremotion/cmodometerdata/startdate)
- [`var verticalAccuracy: CLLocationAccuracy`](https://developer.apple.com/documentation/coremotion/cmodometerdata/verticalaccuracy)
- [`CMOdometerOriginDevice`](https://developer.apple.com/documentation/coremotion/cmodometerorigindevice)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/coremotion/cmodometerorigindevice/init(rawvalue:))
- [`case local`](https://developer.apple.com/documentation/coremotion/cmodometerorigindevice/local)
- [`case remote`](https://developer.apple.com/documentation/coremotion/cmodometerorigindevice/remote)
- [`case unknown`](https://developer.apple.com/documentation/coremotion/cmodometerorigindevice/unknown)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmpedometerdata/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmpedometerevent/init(coder:))
- [`CMPedometerEventHandler`](https://developer.apple.com/documentation/coremotion/cmpedometereventhandler)
- [`CMRecordedDeviceMotion`](https://developer.apple.com/documentation/coremotion/cmrecordeddevicemotion)
- [`var identifier: UInt64`](https://developer.apple.com/documentation/coremotion/cmrecordeddevicemotion/identifier)
- [`var startDate: Date`](https://developer.apple.com/documentation/coremotion/cmrecordeddevicemotion/startdate)
- [`CMRecordedPressureData`](https://developer.apple.com/documentation/coremotion/cmrecordedpressuredata)
- [`var identifier: UInt64`](https://developer.apple.com/documentation/coremotion/cmrecordedpressuredata/identifier)
- [`var startDate: Date`](https://developer.apple.com/documentation/coremotion/cmrecordedpressuredata/startdate)
- [`CMRecordedRotationRateData`](https://developer.apple.com/documentation/coremotion/cmrecordedrotationratedata)
- [`var startDate: Date`](https://developer.apple.com/documentation/coremotion/cmrecordedrotationratedata/startdate)
- [`CMRotationRateData`](https://developer.apple.com/documentation/coremotion/cmrotationratedata)
- [`var rotationRate: CMRotationRate`](https://developer.apple.com/documentation/coremotion/cmrotationratedata/rotationrate)
- [`CMStepQueryHandler`](https://developer.apple.com/documentation/coremotion/cmstepqueryhandler)
- [`CMStepUpdateHandler`](https://developer.apple.com/documentation/coremotion/cmstepupdatehandler)
- [`CMTremorResult`](https://developer.apple.com/documentation/coremotion/cmtremorresult)
- [`var endDate: Date`](https://developer.apple.com/documentation/coremotion/cmtremorresult/enddate)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/coremotion/cmtremorresult/init(coder:))
- [`var percentMild: Float`](https://developer.apple.com/documentation/coremotion/cmtremorresult/percentmild)
- [`var percentModerate: Float`](https://developer.apple.com/documentation/coremotion/cmtremorresult/percentmoderate)
- [`var percentNone: Float`](https://developer.apple.com/documentation/coremotion/cmtremorresult/percentnone)
- [`var percentSlight: Float`](https://developer.apple.com/documentation/coremotion/cmtremorresult/percentslight)
- [`var percentStrong: Float`](https://developer.apple.com/documentation/coremotion/cmtremorresult/percentstrong)
- [`var percentUnknown: Float`](https://developer.apple.com/documentation/coremotion/cmtremorresult/percentunknown)
- [`var startDate: Date`](https://developer.apple.com/documentation/coremotion/cmtremorresult/startdate)

</details>
<!-- /generated:missing -->
