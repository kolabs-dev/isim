# WorkoutKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 69.1% of Apple's iOS API (105 of 152, exact) · **Rows:** 2: 1 ✅ 1 🧩 · **iOS:** 17.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [WorkoutKit](https://developer.apple.com/documentation/workoutkit) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Approach:** stub, like Apple's Simulator: no paired Apple Watch to schedule on (`isim/swift/overlays/WorkoutKit`).
  The plan types are values the app builds; HealthKit's `HKWorkoutActivityType` and the workout location types come
  with them.
- **Objective-C / C interface:** Swift only, as on iOS.
- **Versus Apple's Simulator:** the same.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `WorkoutScheduler` (`shared`, `isSupported`, `authorizationState`, `requestAuthorization()`, `scheduledWorkouts`, `schedule(_:at:)`, `remove(_:at:)`, `removeAllWorkouts()`, `markComplete(_:at:)`, `maxAllowedScheduledWorkoutCount`) | 🧩 | 17.0 | stub: not supported; authorization stays not determined (no prompt), scheduling does nothing and nothing is scheduled. Tested (HelloAccessories: test_devices) |
| Plans: `WorkoutPlan`, `ScheduledWorkoutPlan`, `SingleGoalWorkout`, `CustomWorkout`, `PacerWorkout`, `SwimBikeRunWorkout`, `WorkoutGoal`, `IntervalBlock`, `IntervalStep`, `WorkoutStep`, `WorkoutAlert` (heart rate zone and range, speed, cadence, power) | ✅ | 17.0 | adapted: values the app builds and reads back. Not yet: the remaining alert kinds, `openInWorkoutApp`, plan export (`dataRepresentation`). Tested (HelloAccessories: test_devices) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
47 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`init(target: ClosedRange<Measurement<UnitFrequency>>)`](https://developer.apple.com/documentation/workoutkit/cadencerangealert/init(target:))
- [`var targetQuantityLowerBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/cadencerangealert/targetquantitylowerbound)
- [`var targetQuantityUpperBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/cadencerangealert/targetquantityupperbound)
- [`CadenceThresholdAlert`](https://developer.apple.com/documentation/workoutkit/cadencethresholdalert)
- [`init(target: Measurement<UnitFrequency>)`](https://developer.apple.com/documentation/workoutkit/cadencethresholdalert/init(target:))
- [`var target: Measurement<UnitFrequency>`](https://developer.apple.com/documentation/workoutkit/cadencethresholdalert/target)
- [`var targetQuantity: HKQuantity`](https://developer.apple.com/documentation/workoutkit/cadencethresholdalert/targetquantity)
- [`static func supportsAlert(any WorkoutAlert, activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) -> Bool`](https://developer.apple.com/documentation/workoutkit/customworkout/supportsalert(_:activity:location:))
- [`var targetQuantityLowerBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/heartraterangealert/targetquantitylowerbound)
- [`var targetQuantityUpperBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/heartraterangealert/targetquantityupperbound)
- [`init(target: ClosedRange<Measurement<UnitPower>>)`](https://developer.apple.com/documentation/workoutkit/powerrangealert/init(target:))
- [`var targetQuantityLowerBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/powerrangealert/targetquantitylowerbound)
- [`var targetQuantityUpperBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/powerrangealert/targetquantityupperbound)
- [`PowerThresholdAlert`](https://developer.apple.com/documentation/workoutkit/powerthresholdalert)
- [`init(target: Measurement<UnitPower>)`](https://developer.apple.com/documentation/workoutkit/powerthresholdalert/init(target:))
- [`init(target: Measurement<UnitPower>, metric: WorkoutAlertMetric)`](https://developer.apple.com/documentation/workoutkit/powerthresholdalert/init(target:metric:))
- [`var target: Measurement<UnitPower>`](https://developer.apple.com/documentation/workoutkit/powerthresholdalert/target)
- [`var targetQuantity: HKQuantity`](https://developer.apple.com/documentation/workoutkit/powerthresholdalert/targetquantity)
- [`PowerZoneAlert`](https://developer.apple.com/documentation/workoutkit/powerzonealert)
- [`init(zone: Int)`](https://developer.apple.com/documentation/workoutkit/powerzonealert/init(zone:))
- [`var zone: Int`](https://developer.apple.com/documentation/workoutkit/powerzonealert/zone)
- [`var targetQuantityLowerBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/speedrangealert/targetquantitylowerbound)
- [`var targetQuantityUpperBound: HKQuantity`](https://developer.apple.com/documentation/workoutkit/speedrangealert/targetquantityupperbound)
- [`SpeedThresholdAlert`](https://developer.apple.com/documentation/workoutkit/speedthresholdalert)
- [`init(target: Measurement<UnitSpeed>, metric: WorkoutAlertMetric)`](https://developer.apple.com/documentation/workoutkit/speedthresholdalert/init(target:metric:))
- [`var target: Measurement<UnitSpeed>`](https://developer.apple.com/documentation/workoutkit/speedthresholdalert/target)
- [`var targetQuantity: HKQuantity`](https://developer.apple.com/documentation/workoutkit/speedthresholdalert/targetquantity)
- [`StateError`](https://developer.apple.com/documentation/workoutkit/stateerror)
- [`case watchNotPaired`](https://developer.apple.com/documentation/workoutkit/stateerror/watchnotpaired)
- [`case workoutApplicationNotInstalled`](https://developer.apple.com/documentation/workoutkit/stateerror/workoutapplicationnotinstalled)
- [`static func cadence(Double, unit: UnitFrequency) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/cadence(_:unit:)-3fnpg)
- [`static func cadence(ClosedRange<Double>, unit: UnitFrequency) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/cadence(_:unit:)-y8da)
- [`static func heartRate(ClosedRange<Double>, unit: UnitFrequency) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/heartrate(_:unit:))
- [`static func heartRate(zone: Int) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/heartrate(zone:))
- [`static func power(Double, unit: UnitPower) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/power(_:unit:)-289mz)
- [`static func power(ClosedRange<Double>, unit: UnitPower) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/power(_:unit:)-57ekz)
- [`static func power(Double, unit: UnitPower, metric: WorkoutAlertMetric) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/power(_:unit:metric:)-2847m)
- [`static func power(ClosedRange<Double>, unit: UnitPower, metric: WorkoutAlertMetric) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/power(_:unit:metric:)-5c94p)
- [`static func power(zone: Int) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/power(zone:))
- [`static func speed(ClosedRange<Double>, unit: UnitSpeed, metric: WorkoutAlertMetric) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/speed(_:unit:metric:)-1o2j)
- [`static func speed(Double, unit: UnitSpeed, metric: WorkoutAlertMetric) -> Self`](https://developer.apple.com/documentation/workoutkit/workoutalert/speed(_:unit:metric:)-4zald)
- [`func supports(activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) -> Bool`](https://developer.apple.com/documentation/workoutkit/workoutalert/supports(activity:location:))
- [`static var countPerMinute: UnitFrequency`](https://developer.apple.com/documentation/workoutkit/workoutalertmetric/countperminute)
- [`var dataRepresentation: Data`](https://developer.apple.com/documentation/workoutkit/workoutplan/datarepresentation)
- [`init(from: Data) throws`](https://developer.apple.com/documentation/workoutkit/workoutplan/init(from:))
- [`var activity: HKWorkoutActivityType`](https://developer.apple.com/documentation/workoutkit/workoutplan/workout-swift.enum/activity)
- [`init(goal: WorkoutGoal, alert: (any WorkoutAlert)?)`](https://developer.apple.com/documentation/workoutkit/workoutstep/init(goal:alert:))

</details>
<!-- /generated:missing -->
