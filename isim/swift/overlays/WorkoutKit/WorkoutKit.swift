// isim WorkoutKit (self-authored, iOS API names): workout plans an iPhone app schedules on the paired Apple Watch.
// Like Apple's Simulator, no Apple Watch is paired: WorkoutScheduler.isSupported is false, authorization is not
// determined (no prompt is shown), scheduling does nothing and the scheduled workouts are empty. The plan types are
// values, so apps build their plans and run their "not supported" paths.
@preconcurrency import Foundation
import HealthKit

// MARK: - goals and alerts
public enum WorkoutGoal: Hashable, Sendable {
    case open
    case distance(Double, UnitLength)
    case time(Double, UnitDuration)
    case energy(Double, UnitEnergy)
    case poolSwimDistanceWithTime(Measurement<UnitLength>, Measurement<UnitDuration>)
}

public enum WorkoutAlertMetric: Hashable, Sendable { case current, average }
/// an alert a workout step raises on the watch
public protocol WorkoutAlert: Sendable {
    var metric: WorkoutAlertMetric { get }
}
public struct HeartRateZoneAlert: WorkoutAlert, Hashable {
    public var zone: Int
    public var metric: WorkoutAlertMetric { .current }
    public init(zone: Int) { self.zone = zone }
}
public struct HeartRateRangeAlert: WorkoutAlert, Hashable {
    public var target: ClosedRange<Measurement<UnitFrequency>>
    public var metric: WorkoutAlertMetric { .current }
    public init(target: ClosedRange<Measurement<UnitFrequency>>) { self.target = target }
}
public struct SpeedRangeAlert: WorkoutAlert, Hashable {
    public var target: ClosedRange<Measurement<UnitSpeed>>
    public var metric: WorkoutAlertMetric
    public init(target: ClosedRange<Measurement<UnitSpeed>>, metric: WorkoutAlertMetric) { self.target = target; self.metric = metric }
}
public struct CadenceRangeAlert: WorkoutAlert, Hashable {
    public var target: ClosedRange<Measurement<UnitFrequency>>
    public var metric: WorkoutAlertMetric
    public init(target: ClosedRange<Measurement<UnitFrequency>>, metric: WorkoutAlertMetric = .current) { self.target = target; self.metric = metric }
}
public struct PowerRangeAlert: WorkoutAlert, Hashable {
    public var target: ClosedRange<Measurement<UnitPower>>
    public var metric: WorkoutAlertMetric
    public init(target: ClosedRange<Measurement<UnitPower>>, metric: WorkoutAlertMetric = .current) { self.target = target; self.metric = metric }
}

// MARK: - steps and blocks
public struct WorkoutStep: Sendable {
    public var goal: WorkoutGoal
    public var alert: (any WorkoutAlert)?
    public var displayName: String?
    public init(goal: WorkoutGoal = .open, alert: (any WorkoutAlert)? = nil, displayName: String? = nil) {
        self.goal = goal; self.alert = alert; self.displayName = displayName
    }
}
public struct IntervalStep: Sendable {
    public enum Purpose: Hashable, Sendable { case work, recovery }
    public var purpose: Purpose
    public var step: WorkoutStep
    public init(_ purpose: Purpose, step: WorkoutStep = WorkoutStep()) { self.purpose = purpose; self.step = step }
    public init(_ purpose: Purpose, goal: WorkoutGoal = .open, alert: (any WorkoutAlert)? = nil) {
        self.purpose = purpose; step = WorkoutStep(goal: goal, alert: alert)
    }
}
public struct IntervalBlock: Sendable {
    public var steps: [IntervalStep]
    public var iterations: Int
    public init(steps: [IntervalStep] = [], iterations: Int = 1) { self.steps = steps; self.iterations = iterations }
}

// MARK: - workouts
public struct SingleGoalWorkout: Sendable {
    public var activity: HKWorkoutActivityType
    public var location: HKWorkoutSessionLocationType
    public var swimmingLocation: HKWorkoutSwimmingLocationType
    public var goal: WorkoutGoal
    public init(activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType = .unknown,
                swimmingLocation: HKWorkoutSwimmingLocationType = .unknown, goal: WorkoutGoal) {
        self.activity = activity; self.location = location; self.swimmingLocation = swimmingLocation; self.goal = goal
    }
    public static func supportsActivity(_ activity: HKWorkoutActivityType) -> Bool { activity != .swimBikeRun }
    public static func supportsGoal(_ goal: WorkoutGoal, activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) -> Bool {
        if case .poolSwimDistanceWithTime = goal { return activity == .swimming }
        return true
    }
}
public struct CustomWorkout: Sendable {
    public var activity: HKWorkoutActivityType
    public var location: HKWorkoutSessionLocationType
    public var displayName: String?
    public var warmup: WorkoutStep?
    public var blocks: [IntervalBlock]
    public var cooldown: WorkoutStep?
    public init(activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType = .unknown, displayName: String? = nil,
                warmup: WorkoutStep? = nil, blocks: [IntervalBlock], cooldown: WorkoutStep? = nil) {
        self.activity = activity; self.location = location; self.displayName = displayName
        self.warmup = warmup; self.blocks = blocks; self.cooldown = cooldown
    }
    public static func supportsActivity(_ activity: HKWorkoutActivityType) -> Bool { activity != .swimBikeRun }
    public static func supportsGoal(_ goal: WorkoutGoal, activity: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) -> Bool {
        if case .poolSwimDistanceWithTime = goal { return false }
        return true
    }
}
public struct PacerWorkout: Sendable {
    public var activity: HKWorkoutActivityType
    public var location: HKWorkoutSessionLocationType
    public var distance: Measurement<UnitLength>
    public var time: Measurement<UnitDuration>
    public init(activity: HKWorkoutActivityType = .running, location: HKWorkoutSessionLocationType = .unknown,
                distance: Measurement<UnitLength>, time: Measurement<UnitDuration>) {
        self.activity = activity; self.location = location; self.distance = distance; self.time = time
    }
    public static func supportsActivity(_ activity: HKWorkoutActivityType) -> Bool { [.running, .walking, .cycling].contains(activity) }
}
public struct SwimBikeRunWorkout: Sendable {
    public enum Activity: Hashable, Sendable {
        case swimming(HKWorkoutSwimmingLocationType)
        case cycling(HKWorkoutSessionLocationType)
        case running(HKWorkoutSessionLocationType)
    }
    public var activities: [Activity]
    public var displayName: String?
    public init(activities: [Activity], displayName: String? = nil) { self.activities = activities; self.displayName = displayName }
    public static func supportsActivityOrdering(_ activities: [Activity]) -> Bool { !activities.isEmpty }
}

// MARK: - plans
public struct WorkoutPlan: Identifiable, Sendable {
    public enum Workout: Sendable {
        case goal(SingleGoalWorkout)
        case custom(CustomWorkout)
        case pacer(PacerWorkout)
        case swimBikeRun(SwimBikeRunWorkout)
    }
    public var workout: Workout
    public var id: UUID
    public init(_ workout: Workout, id: UUID = UUID()) { self.workout = workout; self.id = id }
}
public struct ScheduledWorkoutPlan: Identifiable, Sendable {
    public var plan: WorkoutPlan
    public var date: DateComponents
    public var complete: Bool
    public var id: UUID { plan.id }
    public init(_ plan: WorkoutPlan, date: DateComponents) { self.plan = plan; self.date = date; complete = false }
}

// MARK: - scheduler
/// schedules workout plans on the paired Apple Watch: there is none on isim, like the Simulator
public final class WorkoutScheduler: @unchecked Sendable {
    public enum AuthorizationState: Hashable, Sendable { case notDetermined, restricted, denied, authorized }
    public static let shared = WorkoutScheduler()
    public static var isSupported: Bool { false }
    public static var maxAllowedScheduledWorkoutCount: Int { 15 }
    private init() {}
    public var authorizationState: AuthorizationState { get async { .notDetermined } }
    /// no prompt: there is no paired watch to schedule on
    public func requestAuthorization() async -> AuthorizationState {
        NSLog("isim WorkoutKit: no paired Apple Watch (like the Simulator); workout scheduling is not supported")
        return .notDetermined
    }
    public var scheduledWorkouts: [ScheduledWorkoutPlan] { get async { [] } }
    public func schedule(_ plan: WorkoutPlan, at date: DateComponents) async {
        NSLog("isim WorkoutKit: plan %@ not scheduled: no paired Apple Watch", plan.id.uuidString)
    }
    public func remove(_ plan: WorkoutPlan, at date: DateComponents) async {}
    public func removeAllWorkouts() async {}
    public func markComplete(_ plan: WorkoutPlan, at date: DateComponents) async {}
}
