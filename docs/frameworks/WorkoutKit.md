# WorkoutKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
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
<!-- /generated:missing -->
