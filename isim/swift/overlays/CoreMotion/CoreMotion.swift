// isim Core Motion (self-authored, iOS API names).
//
// Adapted: the Simulator reports no motion hardware at all; isim simulates an iPhone held upright and at rest so motion
// code paths can run: the accelerometer reads gravity (0, -1, 0) g, the gyroscope 0 rad/s, device motion has
// gravity (0, -1, 0), no user acceleration and pitch = π/2. ISIM_MOTION=unavailable reports no sensors (exactly like
// the Simulator). Step counting, motion activity and the altimeter are unavailable, like the Simulator.
import Foundation

public struct CMAcceleration: Sendable { public var x, y, z: Double; public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z } }
public struct CMRotationRate: Sendable { public var x, y, z: Double; public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z } }
public struct CMMagneticField: Sendable { public var x, y, z: Double; public init() { x = 0; y = 0; z = 0 }
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z } }
public struct CMQuaternion: Sendable { public var x, y, z, w: Double; public init() { x = 0; y = 0; z = 0; w = 1 }
    public init(x: Double, y: Double, z: Double, w: Double) { self.x = x; self.y = y; self.z = z; self.w = w } }
public struct CMRotationMatrix: Sendable {
    public var m11, m12, m13, m21, m22, m23, m31, m32, m33: Double
    public init() { m11 = 1; m12 = 0; m13 = 0; m21 = 0; m22 = 1; m23 = 0; m31 = 0; m32 = 0; m33 = 1 }
    public init(m11: Double, m12: Double, m13: Double, m21: Double, m22: Double, m23: Double, m31: Double, m32: Double, m33: Double) {
        self.m11 = m11; self.m12 = m12; self.m13 = m13; self.m21 = m21; self.m22 = m22; self.m23 = m23; self.m31 = m31; self.m32 = m32; self.m33 = m33
    }
}
public enum CMMagneticFieldCalibrationAccuracy: Int32, Sendable { case uncalibrated = -1, low = 0, medium = 1, high = 2 }
public struct CMCalibratedMagneticField: Sendable {
    public var field: CMMagneticField
    public var accuracy: CMMagneticFieldCalibrationAccuracy
    public init() { field = CMMagneticField(); accuracy = .uncalibrated }
    public init(field: CMMagneticField, accuracy: CMMagneticFieldCalibrationAccuracy) { self.field = field; self.accuracy = accuracy }
}
public struct CMAttitudeReferenceFrame: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let xArbitraryZVertical = CMAttitudeReferenceFrame(rawValue: 1)
    public static let xArbitraryCorrectedZVertical = CMAttitudeReferenceFrame(rawValue: 2)
    public static let xMagneticNorthZVertical = CMAttitudeReferenceFrame(rawValue: 4)
    public static let xTrueNorthZVertical = CMAttitudeReferenceFrame(rawValue: 8)
}
public enum CMDeviceMotionSensorLocation: Int, Sendable { case `default` = 0, headphoneLeft, headphoneRight }
public enum CMAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted, denied, authorized }

public let CMErrorDomain = "CMErrorDomain"
public struct CMError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case null = 100, deviceRequiresMovement, trueNorthNotAvailable, unknown, motionActivityNotAvailable
        case motionActivityNotAuthorized, motionActivityNotEntitled, invalidParameter, invalidAction, notAvailable
        case notEntitled, notAuthorized, nilData, size
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CMErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public var errorDescription: String? { "The operation couldn’t be completed. (CMErrorDomain error \(code.rawValue).)" }
}

open class CMLogItem: NSObject, @unchecked Sendable {
    open private(set) var timestamp: TimeInterval
    init(_ t: TimeInterval) { timestamp = t }
}
open class CMAccelerometerData: CMLogItem, @unchecked Sendable {
    open private(set) var acceleration: CMAcceleration
    init(_ a: CMAcceleration, _ t: TimeInterval) { acceleration = a; super.init(t) }
    open override var description: String { String(format: "x %f y %f z %f @ %f", acceleration.x, acceleration.y, acceleration.z, timestamp) }
}
open class CMGyroData: CMLogItem, @unchecked Sendable {
    open private(set) var rotationRate: CMRotationRate
    init(_ r: CMRotationRate, _ t: TimeInterval) { rotationRate = r; super.init(t) }
}
open class CMMagnetometerData: CMLogItem, @unchecked Sendable {
    open private(set) var magneticField: CMMagneticField
    init(_ m: CMMagneticField, _ t: TimeInterval) { magneticField = m; super.init(t) }
}
open class CMAttitude: NSObject, NSCopying, @unchecked Sendable {
    open private(set) var roll: Double
    open private(set) var pitch: Double
    open private(set) var yaw: Double
    init(roll: Double, pitch: Double, yaw: Double) { self.roll = roll; self.pitch = pitch; self.yaw = yaw }
    open var quaternion: CMQuaternion {
        let cr = cos(roll / 2), sr = sin(roll / 2), cp = cos(pitch / 2), sp = sin(pitch / 2), cy = cos(yaw / 2), sy = sin(yaw / 2)
        // Core Motion's convention: pitch about x, roll about y, yaw about z
        return CMQuaternion(x: sp * cr * cy - cp * sr * sy, y: cp * sr * cy + sp * cr * sy, z: cp * cr * sy - sp * sr * cy, w: cp * cr * cy + sp * sr * sy)
    }
    open var rotationMatrix: CMRotationMatrix {
        let q = quaternion
        return CMRotationMatrix(m11: 1 - 2 * (q.y * q.y + q.z * q.z), m12: 2 * (q.x * q.y + q.z * q.w), m13: 2 * (q.x * q.z - q.y * q.w),
                                m21: 2 * (q.x * q.y - q.z * q.w), m22: 1 - 2 * (q.x * q.x + q.z * q.z), m23: 2 * (q.y * q.z + q.x * q.w),
                                m31: 2 * (q.x * q.z + q.y * q.w), m32: 2 * (q.y * q.z - q.x * q.w), m33: 1 - 2 * (q.x * q.x + q.y * q.y))
    }
    open func multiply(byInverseOf attitude: CMAttitude) { roll -= attitude.roll; pitch -= attitude.pitch; yaw -= attitude.yaw }
    public func copy(with zone: OpaquePointer? = nil) -> Any { CMAttitude(roll: roll, pitch: pitch, yaw: yaw) }
}
open class CMDeviceMotion: CMLogItem, @unchecked Sendable {
    open private(set) var attitude: CMAttitude
    open private(set) var rotationRate: CMRotationRate
    open private(set) var gravity: CMAcceleration
    open private(set) var userAcceleration: CMAcceleration
    open private(set) var magneticField: CMCalibratedMagneticField
    open private(set) var heading: Double
    open private(set) var sensorLocation: CMDeviceMotionSensorLocation = .default
    init(frame: CMAttitudeReferenceFrame, _ t: TimeInterval) {
        attitude = CMAttitude(roll: 0, pitch: .pi / 2, yaw: 0)
        rotationRate = CMRotationRate(); gravity = _CMDevice.gravity; userAcceleration = CMAcceleration()
        let north = frame.contains(.xMagneticNorthZVertical) || frame.contains(.xTrueNorthZVertical)
        magneticField = CMCalibratedMagneticField(field: north ? CMMagneticField(x: 0, y: 0, z: -42) : CMMagneticField(), accuracy: north ? .high : .uncalibrated)
        heading = north ? 0 : -1
        super.init(t)
    }
}

public typealias CMAccelerometerHandler = (CMAccelerometerData?, Error?) -> Void
public typealias CMGyroHandler = (CMGyroData?, Error?) -> Void
public typealias CMMagnetometerHandler = (CMMagnetometerData?, Error?) -> Void
public typealias CMDeviceMotionHandler = (CMDeviceMotion?, Error?) -> Void

enum _CMDevice {
    static let available: Bool = getenv("ISIM_MOTION").map { String(cString: $0).lowercased() != "unavailable" } ?? true
    static let gravity = CMAcceleration(x: 0, y: -1, z: 0)
    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

open class CMMotionManager: NSObject, @unchecked Sendable {
    open var accelerometerUpdateInterval: TimeInterval = 0.01
    open var gyroUpdateInterval: TimeInterval = 0.01
    open var magnetometerUpdateInterval: TimeInterval = 0.01
    open var deviceMotionUpdateInterval: TimeInterval = 0.01
    open var showsDeviceMovementDisplay = false
    open private(set) var attitudeReferenceFrame: CMAttitudeReferenceFrame = .xArbitraryZVertical

    private var timers: [String: Timer] = [:]
    private var active: Set<String> = []

    public override init() { super.init() }
    deinit { timers.values.forEach { $0.invalidate() } }

    open var isAccelerometerAvailable: Bool { _CMDevice.available }
    open var isGyroAvailable: Bool { _CMDevice.available }
    open var isMagnetometerAvailable: Bool { _CMDevice.available }
    open var isDeviceMotionAvailable: Bool { _CMDevice.available }
    open var isAccelerometerActive: Bool { active.contains("a") }
    open var isGyroActive: Bool { active.contains("g") }
    open var isMagnetometerActive: Bool { active.contains("m") }
    open var isDeviceMotionActive: Bool { active.contains("d") }
    open class func availableAttitudeReferenceFrames() -> CMAttitudeReferenceFrame {
        _CMDevice.available ? [.xArbitraryZVertical, .xArbitraryCorrectedZVertical, .xMagneticNorthZVertical, .xTrueNorthZVertical] : []
    }

    // pull: the latest sample while active
    open var accelerometerData: CMAccelerometerData? { isAccelerometerActive ? CMAccelerometerData(_CMDevice.gravity, _CMDevice.now) : nil }
    open var gyroData: CMGyroData? { isGyroActive ? CMGyroData(CMRotationRate(), _CMDevice.now) : nil }
    open var magnetometerData: CMMagnetometerData? { isMagnetometerActive ? CMMagnetometerData(CMMagneticField(x: 18.4, y: -9.2, z: -41.7), _CMDevice.now) : nil }
    open var deviceMotion: CMDeviceMotion? { isDeviceMotionActive ? CMDeviceMotion(frame: attitudeReferenceFrame, _CMDevice.now) : nil }

    private func start(_ key: String, _ interval: TimeInterval, _ queue: OperationQueue?, _ tick: (() -> Void)?) {
        guard _CMDevice.available else { return }
        active.insert(key)
        timers[key]?.invalidate(); timers[key] = nil
        guard let tick else { return }
        let t = Timer(timeInterval: max(interval, 0.01), repeats: true) { _ in
            if let queue, queue !== OperationQueue.main { queue.addOperation { tick() } } else { tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timers[key] = t
    }
    private func stop(_ key: String) { active.remove(key); timers[key]?.invalidate(); timers[key] = nil }

    open func startAccelerometerUpdates() { start("a", accelerometerUpdateInterval, nil, nil) }
    open func startAccelerometerUpdates(to queue: OperationQueue, withHandler handler: @escaping CMAccelerometerHandler) {
        start("a", accelerometerUpdateInterval, queue) { handler(CMAccelerometerData(_CMDevice.gravity, _CMDevice.now), nil) }
    }
    open func stopAccelerometerUpdates() { stop("a") }
    open func startGyroUpdates() { start("g", gyroUpdateInterval, nil, nil) }
    open func startGyroUpdates(to queue: OperationQueue, withHandler handler: @escaping CMGyroHandler) {
        start("g", gyroUpdateInterval, queue) { handler(CMGyroData(CMRotationRate(), _CMDevice.now), nil) }
    }
    open func stopGyroUpdates() { stop("g") }
    open func startMagnetometerUpdates() { start("m", magnetometerUpdateInterval, nil, nil) }
    open func startMagnetometerUpdates(to queue: OperationQueue, withHandler handler: @escaping CMMagnetometerHandler) {
        start("m", magnetometerUpdateInterval, queue) { handler(CMMagnetometerData(CMMagneticField(x: 18.4, y: -9.2, z: -41.7), _CMDevice.now), nil) }
    }
    open func stopMagnetometerUpdates() { stop("m") }
    open func startDeviceMotionUpdates() { start("d", deviceMotionUpdateInterval, nil, nil) }
    open func startDeviceMotionUpdates(using referenceFrame: CMAttitudeReferenceFrame) { attitudeReferenceFrame = referenceFrame; startDeviceMotionUpdates() }
    open func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler) {
        let frame = attitudeReferenceFrame
        start("d", deviceMotionUpdateInterval, queue) { handler(CMDeviceMotion(frame: frame, _CMDevice.now), nil) }
    }
    open func startDeviceMotionUpdates(using referenceFrame: CMAttitudeReferenceFrame, to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler) {
        attitudeReferenceFrame = referenceFrame
        startDeviceMotionUpdates(to: queue, withHandler: handler)
    }
    open func stopDeviceMotionUpdates() { stop("d") }
}

// MARK: - Sensors the Simulator does not have

open class CMPedometerData: NSObject, @unchecked Sendable {
    open private(set) var startDate = Date(), endDate = Date()
    open private(set) var numberOfSteps: NSNumber = 0
    open private(set) var distance: NSNumber?
    open private(set) var floorsAscended: NSNumber?, floorsDescended: NSNumber?
    open private(set) var currentPace: NSNumber?, currentCadence: NSNumber?, averageActivePace: NSNumber?
}
public enum CMPedometerEventType: Int, Sendable { case pause = 0, resume }
open class CMPedometerEvent: NSObject, @unchecked Sendable {
    open private(set) var date = Date()
    open private(set) var type: CMPedometerEventType = .pause
}
public typealias CMPedometerHandler = (CMPedometerData?, Error?) -> Void

open class CMPedometer: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open class func isStepCountingAvailable() -> Bool { false }
    open class func isDistanceAvailable() -> Bool { false }
    open class func isFloorCountingAvailable() -> Bool { false }
    open class func isPaceAvailable() -> Bool { false }
    open class func isCadenceAvailable() -> Bool { false }
    open class func isPedometerEventTrackingAvailable() -> Bool { false }
    open class func authorizationStatus() -> CMAuthorizationStatus { .notDetermined }
    open func queryPedometerData(from start: Date, to end: Date, withHandler handler: @escaping CMPedometerHandler) {
        DispatchQueue.global().async { handler(nil, CMError(.motionActivityNotAvailable)) }
    }
    open func startUpdates(from start: Date, withHandler handler: @escaping CMPedometerHandler) {
        DispatchQueue.global().async { handler(nil, CMError(.motionActivityNotAvailable)) }
    }
    open func stopUpdates() {}
    open func startEventUpdates(handler: @escaping (CMPedometerEvent?, Error?) -> Void) {
        DispatchQueue.global().async { handler(nil, CMError(.motionActivityNotAvailable)) }
    }
    open func stopEventUpdates() {}
}

public enum CMMotionActivityConfidence: Int, Sendable { case low = 0, medium, high }
open class CMMotionActivity: CMLogItem, @unchecked Sendable {
    open private(set) var confidence: CMMotionActivityConfidence = .low
    open private(set) var startDate = Date()
    open private(set) var unknown = true, stationary = false, walking = false, running = false, automotive = false, cycling = false
}
public typealias CMMotionActivityHandler = (CMMotionActivity?) -> Void
open class CMMotionActivityManager: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open class func isActivityAvailable() -> Bool { false }
    open class func authorizationStatus() -> CMAuthorizationStatus { .notDetermined }
    open func queryActivityStarting(from start: Date, to end: Date, to queue: OperationQueue, withHandler handler: @escaping ([CMMotionActivity]?, Error?) -> Void) {
        queue.addOperation { handler(nil, CMError(.motionActivityNotAvailable)) }
    }
    open func startActivityUpdates(to queue: OperationQueue, withHandler handler: @escaping CMMotionActivityHandler) {}
    open func stopActivityUpdates() {}
}

open class CMAltitudeData: CMLogItem, @unchecked Sendable {
    open private(set) var relativeAltitude: NSNumber = 0
    open private(set) var pressure: NSNumber = 101.325
}
open class CMAltimeter: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open class func isRelativeAltitudeAvailable() -> Bool { false }
    open class func isAbsoluteAltitudeAvailable() -> Bool { false }
    open class func authorizationStatus() -> CMAuthorizationStatus { .notDetermined }
    open func startRelativeAltitudeUpdates(to queue: OperationQueue, withHandler handler: @escaping (CMAltitudeData?, Error?) -> Void) {
        queue.addOperation { handler(nil, CMError(.notAvailable)) }
    }
    open func stopRelativeAltitudeUpdates() {}
}

open class CMHeadphoneMotionManager: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open var isDeviceMotionAvailable: Bool { false }
    open var isDeviceMotionActive: Bool { false }
    open var deviceMotion: CMDeviceMotion? { nil }
    open class func authorizationStatus() -> CMAuthorizationStatus { .notDetermined }
    open func startDeviceMotionUpdates() {}
    open func startDeviceMotionUpdates(to queue: OperationQueue, withHandler handler: @escaping CMDeviceMotionHandler) {}
    open func stopDeviceMotionUpdates() {}
}
