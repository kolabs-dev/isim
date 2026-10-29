// isim Core Motion: the sensors the Simulator does not have either (issue #414), stubs that answer like it does.
// Headphone motion sees no headphones; batched sensors (iOS 17), the sensor recorder, absolute altitude (iOS 15) and
// water submersion (iOS 16) are unavailable: their handlers, async sequences and delegates get CMError.notAvailable.
import Foundation

// MARK: - headphones

extension CMHeadphoneMotionManager {
    public typealias DeviceMotionHandler = (CMDeviceMotion?, (any Error)?) -> Void
}

@objc(CMHeadphoneMotionManagerDelegate) public protocol CMHeadphoneMotionManagerDelegate: NSObjectProtocol {
    @objc(headphoneMotionManagerDidConnect:) optional func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager)
    @objc(headphoneMotionManagerDidDisconnect:) optional func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager)
}

// MARK: - batched sensors (iOS 17)

@available(iOS 17.0, *)
@objc(CMBatchedSensorManager) open class CMBatchedSensorManager: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open class var authorizationStatus: CMAuthorizationStatus { _CMMotionUsage.status }
    open class var isAccelerometerSupported: Bool { false }
    open class var isDeviceMotionSupported: Bool { false }
    open var accelerometerDataFrequency: Int { 0 }
    open var deviceMotionDataFrequency: Int { 0 }
    open var isAccelerometerActive: Bool { false }
    open var isDeviceMotionActive: Bool { false }
    open var accelerometerBatch: [CMAccelerometerData]? { nil }
    open var deviceMotionBatch: [CMDeviceMotion]? { nil }
    open func startAccelerometerUpdates() {}
    open func startAccelerometerUpdates(handler: @escaping ([CMAccelerometerData]?, (any Error)?) -> Void) {
        DispatchQueue.global().async { handler(nil, CMError(.notAvailable)) }
    }
    open func stopAccelerometerUpdates() {}
    open func startDeviceMotionUpdates() {}
    open func startDeviceMotionUpdates(handler: @escaping ([CMDeviceMotion]?, (any Error)?) -> Void) {
        DispatchQueue.global().async { handler(nil, CMError(.notAvailable)) }
    }
    open func stopDeviceMotionUpdates() {}
    public func accelerometerUpdates() -> AccelerometerUpdates { AccelerometerUpdates() }
    public func deviceMotionUpdates() -> DeviceMotionUpdates { DeviceMotionUpdates() }

    /// the batches as they arrive: on isim the first `next()` throws CMError.notAvailable
    public struct AccelerometerUpdates: AsyncSequence, Sendable {
        public typealias Element = [CMAccelerometerData]
        public struct Iterator: AsyncIteratorProtocol {
            public mutating func next() async throws -> [CMAccelerometerData]? { throw CMError(.notAvailable) }
        }
        public func makeAsyncIterator() -> Iterator { Iterator() }
    }
    public struct DeviceMotionUpdates: AsyncSequence, Sendable {
        public typealias Element = [CMDeviceMotion]
        public struct Iterator: AsyncIteratorProtocol {
            public mutating func next() async throws -> [CMDeviceMotion]? { throw CMError(.notAvailable) }
        }
        public func makeAsyncIterator() -> Iterator { Iterator() }
    }
}

// MARK: - the sensor recorder

@objc(CMRecordedAccelerometerData) open class CMRecordedAccelerometerData: CMAccelerometerData, @unchecked Sendable {
    open private(set) var identifier: UInt64 = 0
    open private(set) var startDate = Date()
}

/// recorded data (isim records none): NSFastEnumeration in Objective-C, a Sequence in Swift
@objc(CMSensorDataList) open class CMSensorDataList: NSObject, NSFastEnumeration, @unchecked Sendable {
    var _items: [AnyObject] = []
    public func countByEnumerating(with state: UnsafeMutablePointer<NSFastEnumerationState>, objects buffer: AutoreleasingUnsafeMutablePointer<AnyObject?>, count len: Int) -> Int {
        0
    }
}
extension CMSensorDataList: Sequence {
    public func makeIterator() -> NSFastEnumerationIterator { NSFastEnumerationIterator(self) }
}

@objc(CMSensorRecorder) open class CMSensorRecorder: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open class func isAccelerometerRecordingAvailable() -> Bool { false }
    open class func authorizationStatus() -> CMAuthorizationStatus { _CMMotionUsage.status }
    @available(*, deprecated, message: "use authorizationStatus()")
    open class func isAuthorizedForRecording() -> Bool { false }
    open func recordAccelerometer(forDuration duration: TimeInterval) {
        NSLog("isim CoreMotion: accelerometer recording is not available (like the Simulator)")
    }
    open func accelerometerData(from fromDate: Date, to toDate: Date) -> CMSensorDataList? { nil }
}

// MARK: - absolute altitude (iOS 15)

@available(iOS 15.0, *)
@objc(CMAbsoluteAltitudeData) open class CMAbsoluteAltitudeData: CMLogItem, @unchecked Sendable {
    open private(set) var altitude: Double = 0
    open private(set) var accuracy: Double = 0
    open private(set) var precision: Double = 0
}
public typealias CMAbsoluteAltitudeHandler = (CMAbsoluteAltitudeData?, (any Error)?) -> Void
public typealias CMAltitudeHandler = (CMAltitudeData?, (any Error)?) -> Void

extension CMAltimeter {
    @available(iOS 15.0, *)
    @objc(startAbsoluteAltitudeUpdatesToQueue:withHandler:)
    public func startAbsoluteAltitudeUpdates(to queue: OperationQueue, withHandler handler: @escaping CMAbsoluteAltitudeHandler) {
        let e = _CMMotionUsage.error(.notAvailable)
        queue.addOperation { handler(nil, e) }
    }
    @available(iOS 15.0, *)
    @objc(stopAbsoluteAltitudeUpdates) public func stopAbsoluteAltitudeUpdates() {}
}

// MARK: - water submersion (iOS 16)

@available(iOS 16.0, *)
@objc(CMWaterSubmersionEvent) open class CMWaterSubmersionEvent: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    @objc public enum State: Int, Sendable { case unknown = 0, notSubmerged = 1, submerged = 2 }
    open private(set) var date = Date()
    open private(set) var state: State = .unknown
    override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) { super.init() }
    open func encode(with coder: NSCoder) {}
    open func copy(with zone: NSZone? = nil) -> Any { self }
}
@available(iOS 16.0, *)
@objc(CMWaterSubmersionMeasurement) open class CMWaterSubmersionMeasurement: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    @objc public enum DepthState: Int, Sendable {
        case unknown = 0, notSubmerged = 100, submergedShallow = 200, submergedDeep = 300, approachingMaxDepth = 400, pastMaxDepth = 500, sensorDepthError = 600
    }
    open private(set) var date = Date()
    open private(set) var depth: Measurement<UnitLength>?
    open private(set) var pressure: Measurement<UnitPressure>?
    open private(set) var surfacePressure = Measurement(value: 101.325, unit: UnitPressure.kilopascals)
    open private(set) var submersionState: DepthState = .unknown
    override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) { super.init() }
    open func encode(with coder: NSCoder) {}
    open func copy(with zone: NSZone? = nil) -> Any { self }
}
@available(iOS 16.0, *)
@objc(CMWaterTemperature) open class CMWaterTemperature: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    open private(set) var date = Date()
    open private(set) var temperature = Measurement(value: 0, unit: UnitTemperature.celsius)
    open private(set) var temperatureUncertainty = Measurement(value: 0, unit: UnitTemperature.celsius)
    override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) { super.init() }
    open func encode(with coder: NSCoder) {}
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

@available(iOS 16.0, *)
@objc(CMWaterSubmersionManagerDelegate) public protocol CMWaterSubmersionManagerDelegate: NSObjectProtocol {
    @objc(manager:didUpdateEvent:) func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent)
    @objc(manager:didUpdateMeasurement:) func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement)
    @objc(manager:didUpdateTemperature:) func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterTemperature)
    @objc(manager:errorOccurred:) func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: any Error)
}

/// no depth gauge: the delegate, once set, gets manager(_:errorOccurred:) with CMError.notAvailable
@available(iOS 16.0, *)
@objc(CMWaterSubmersionManager) open class CMWaterSubmersionManager: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    open class var waterSubmersionAvailable: Bool { false }
    open class var authorizationStatus: CMAuthorizationStatus { _CMMotionUsage.status }
    open var maximumDepth: Measurement<UnitLength>? { nil }
    open weak var delegate: (any CMWaterSubmersionManagerDelegate)? {
        didSet {
            guard let d = delegate else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, d === self.delegate else { return }
                d.manager(self, errorOccurred: CMError(.notAvailable))
            }
        }
    }
}

// MARK: - Objective-C (sdk-src/Frameworks/CoreMotion/CoreMotion.h)

extension CMHeadphoneMotionManager {
    @objc(delegate) var _objc_delegate: (any CMHeadphoneMotionManagerDelegate)? { get { delegate } set { delegate = newValue } }
    @objc(isConnectionStatusActive) var _objc_connectionActive: Bool { isConnectionStatusActive }
    @objc(startConnectionStatusUpdates) func _objc_startConnection() { startConnectionStatusUpdates() }
    @objc(stopConnectionStatusUpdates) func _objc_stopConnection() { stopConnectionStatusUpdates() }
}
@available(iOS 17.0, *)
extension CMBatchedSensorManager {
    @objc(authorizationStatus) class var _objc_authorizationStatus: Int { authorizationStatus.rawValue }
    @objc(isAccelerometerSupported) class var _objc_accelerometerSupported: Bool { isAccelerometerSupported }
    @objc(isDeviceMotionSupported) class var _objc_deviceMotionSupported: Bool { isDeviceMotionSupported }
    @objc(accelerometerDataFrequency) var _objc_accelerometerDataFrequency: Int { accelerometerDataFrequency }
    @objc(deviceMotionDataFrequency) var _objc_deviceMotionDataFrequency: Int { deviceMotionDataFrequency }
    @objc(isAccelerometerActive) var _objc_accelerometerActive: Bool { isAccelerometerActive }
    @objc(isDeviceMotionActive) var _objc_deviceMotionActive: Bool { isDeviceMotionActive }
    @objc(accelerometerBatch) var _objc_accelerometerBatch: [CMAccelerometerData]? { accelerometerBatch }
    @objc(deviceMotionBatch) var _objc_deviceMotionBatch: [CMDeviceMotion]? { deviceMotionBatch }
    @objc(startAccelerometerUpdates) func _objc_startAccelerometer() { startAccelerometerUpdates() }
    @objc(startAccelerometerUpdatesWithHandler:) func _objc_startAccelerometer(_ handler: @escaping ([CMAccelerometerData]?, NSError?) -> Void) {
        startAccelerometerUpdates { d, e in handler(d, e.map { $0 as NSError }) }
    }
    @objc(stopAccelerometerUpdates) func _objc_stopAccelerometer() { stopAccelerometerUpdates() }
    @objc(startDeviceMotionUpdates) func _objc_startDeviceMotion() { startDeviceMotionUpdates() }
    @objc(startDeviceMotionUpdatesWithHandler:) func _objc_startDeviceMotion(_ handler: @escaping ([CMDeviceMotion]?, NSError?) -> Void) {
        startDeviceMotionUpdates { d, e in handler(d, e.map { $0 as NSError }) }
    }
    @objc(stopDeviceMotionUpdates) func _objc_stopDeviceMotion() { stopDeviceMotionUpdates() }
}
extension CMRecordedAccelerometerData {
    @objc(identifier) var _objc_identifier: UInt64 { identifier }
    @objc(startDate) var _objc_startDate: Date { startDate }
}
extension CMSensorRecorder {
    @objc(isAccelerometerRecordingAvailable) class func _objc_available() -> Bool { isAccelerometerRecordingAvailable() }
    @objc(authorizationStatus) class func _objc_authorizationStatus() -> Int { authorizationStatus().rawValue }
    @objc(recordAccelerometerForDuration:) func _objc_record(_ duration: TimeInterval) { recordAccelerometer(forDuration: duration) }
    @objc(accelerometerDataFromDate:toDate:) func _objc_data(_ from: Date, to: Date) -> CMSensorDataList? { accelerometerData(from: from, to: to) }
}
@available(iOS 15.0, *)
extension CMAbsoluteAltitudeData {
    @objc(altitude) var _objc_altitude: Double { altitude }
    @objc(accuracy) var _objc_accuracy: Double { accuracy }
    @objc(precision) var _objc_precision: Double { precision }
}
@available(iOS 16.0, *)
extension CMWaterSubmersionEvent {
    @objc(date) var _objc_date: Date { date }
    @objc(state) var _objc_state: State { state }
}
@available(iOS 16.0, *)
extension CMWaterSubmersionMeasurement {
    @objc(date) var _objc_date: Date { date }
    @objc(depth) var _objc_depth: NSMeasurement? { depth.map { NSMeasurement(doubleValue: $0.value, unit: $0.unit) } }
    @objc(pressure) var _objc_pressure: NSMeasurement? { pressure.map { NSMeasurement(doubleValue: $0.value, unit: $0.unit) } }
    @objc(surfacePressure) var _objc_surfacePressure: NSMeasurement { NSMeasurement(doubleValue: surfacePressure.value, unit: surfacePressure.unit) }
    @objc(submersionState) var _objc_submersionState: DepthState { submersionState }
}
@available(iOS 16.0, *)
extension CMWaterTemperature {
    @objc(date) var _objc_date: Date { date }
    @objc(temperature) var _objc_temperature: NSMeasurement { NSMeasurement(doubleValue: temperature.value, unit: temperature.unit) }
    @objc(temperatureUncertainty) var _objc_temperatureUncertainty: NSMeasurement {
        NSMeasurement(doubleValue: temperatureUncertainty.value, unit: temperatureUncertainty.unit)
    }
}
@available(iOS 16.0, *)
extension CMWaterSubmersionManager {
    @objc(waterSubmersionAvailable) class var _objc_available: Bool { waterSubmersionAvailable }
    @objc(authorizationStatus) class var _objc_authorizationStatus: Int { authorizationStatus.rawValue }
    @objc(maximumDepth) var _objc_maximumDepth: NSMeasurement? { nil }
    @objc(delegate) var _objc_delegate: (any CMWaterSubmersionManagerDelegate)? { get { delegate } set { delegate = newValue } }
}
