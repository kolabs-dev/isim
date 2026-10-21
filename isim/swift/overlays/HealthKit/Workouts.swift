// isim HealthKit: the workout activity and location types (Apple's raw values). WorkoutKit's plans use them.
import Foundation

@objc public enum HKWorkoutActivityType: UInt, Sendable {
    case americanFootball = 1, archery, australianFootball, badminton, baseball, basketball, bowling, boxing, climbing
    case cricket, crossTraining, curling, cycling
    case elliptical = 16, equestrianSports, fencing, fishing, functionalStrengthTraining, golf, gymnastics, handball, hiking
    case hockey, hunting, lacrosse, martialArts, mindAndBody
    case paddleSports = 31, play, preparationAndRecovery, racquetball, rowing, rugby, running, sailing, skatingSports
    case snowSports, soccer, softball, squash, stairClimbing, surfingSports, swimming, tableTennis, tennis, trackAndField
    case traditionalStrengthTraining, volleyball, walking, waterFitness, waterPolo, waterSports, wrestling, yoga
    case barre, coreTraining, crossCountrySkiing, downhillSkiing, flexibility, highIntensityIntervalTraining, jumpRope
    case kickboxing, pilates, snowboarding, stairs, stepTraining, wheelchairWalkPace, wheelchairRunPace, taiChi
    case mixedCardio, handCycling, discSports, fitnessGaming, cardioDance, socialDance, pickleball, cooldown
    case swimBikeRun = 82, transition, underwaterDiving
    case other = 3000
}

@objc public enum HKWorkoutSessionLocationType: Int, Sendable { case unknown = 1, indoor, outdoor }
@objc public enum HKWorkoutSwimmingLocationType: Int, Sendable { case unknown = 0, pool, openWater }
