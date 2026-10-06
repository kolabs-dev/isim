// isim Core Location (self-authored, iOS API names): CLLocationManager with the iOS location permission alert and a
// simulated location, like the Simulator's Features ▸ Location menu.
//
// Simulated location (adapted: there is no GPS):
//   default            Apple Park, Cupertino (37.334900, -122.009020)
//   ISIM_LOCATION=lat,lon        start at a custom location;  ISIM_LOCATION=none  no location (like Location ▸ None)
//   ISIM_LOCATION=lat,lon;lat,lon;...@speed   a route: moves along the points at `speed` m/s (default 10), looping
//   script / --control command   `location LAT LON` (or `location none`) moves the device while apps run; the host
//                                writes $ISIM_DATA/Library/isim/SimulatedLocation and it persists like the Simulator's
//                                custom location
// Permission (remembered per app): ISIM_LOCATION_PERMISSION=once|wheninuse|always|deny answers without the alert.
// CLGeocoder works offline from a small built-in gazetteer (see Geocoder.swift); anything else fails with
// CLError.geocodeFoundNoResult, or CLError.network when ISIM_GEOCODER=offline.
import UIKit

public typealias CLLocationDegrees = Double
public typealias CLLocationDistance = Double
public typealias CLLocationAccuracy = Double
public typealias CLLocationSpeed = Double
public typealias CLLocationSpeedAccuracy = Double
public typealias CLLocationDirection = Double
public typealias CLLocationDirectionAccuracy = Double
public typealias CLHeadingComponentValue = Double

public struct CLLocationCoordinate2D: @unchecked Sendable {
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public init() { latitude = 0; longitude = 0 }
    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) { self.latitude = latitude; self.longitude = longitude }
}
public func CLLocationCoordinate2DMake(_ latitude: CLLocationDegrees, _ longitude: CLLocationDegrees) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
}
public func CLLocationCoordinate2DIsValid(_ c: CLLocationCoordinate2D) -> Bool {
    c.latitude >= -90 && c.latitude <= 90 && c.longitude >= -180 && c.longitude <= 180
}
public let kCLLocationCoordinate2DInvalid = CLLocationCoordinate2D(latitude: -180, longitude: -180)

public let kCLLocationAccuracyBestForNavigation: CLLocationAccuracy = -2
public let kCLLocationAccuracyBest: CLLocationAccuracy = -1
public let kCLLocationAccuracyNearestTenMeters: CLLocationAccuracy = 10
public let kCLLocationAccuracyHundredMeters: CLLocationAccuracy = 100
public let kCLLocationAccuracyKilometer: CLLocationAccuracy = 1000
public let kCLLocationAccuracyThreeKilometers: CLLocationAccuracy = 3000
public let kCLLocationAccuracyReduced: CLLocationAccuracy = 3000
public let kCLDistanceFilterNone: CLLocationDistance = -1
public let kCLHeadingFilterNone: CLLocationDegrees = -1
public let CLLocationDistanceMax: CLLocationDistance = .greatestFiniteMagnitude
public let CLTimeIntervalMax: TimeInterval = .greatestFiniteMagnitude
public let kCLErrorDomain = "kCLErrorDomain"
public let kCLErrorUserInfoAlternateRegionKey = "alternateRegion"

@objc public enum CLAuthorizationStatus: Int32, Sendable {
    case notDetermined = 0, restricted = 1, denied = 2, authorizedAlways = 3, authorizedWhenInUse = 4
    @available(*, deprecated, renamed: "authorizedAlways") public static var authorized: CLAuthorizationStatus { .authorizedAlways }
}
@objc public enum CLAccuracyAuthorization: Int, Sendable { case fullAccuracy = 0, reducedAccuracy = 1 }
@objc public enum CLActivityType: Int, Sendable { case other = 1, automotiveNavigation, fitness, otherNavigation, airborne }
@objc public enum CLRegionState: Int, Sendable { case unknown = 0, inside, outside }
@objc public enum CLDeviceOrientation: Int32, Sendable { case unknown = 0, portrait, portraitUpsideDown, landscapeLeft, landscapeRight, faceUp, faceDown }

public struct CLError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case locationUnknown = 0, denied, network, headingFailure, regionMonitoringDenied, regionMonitoringFailure
        case regionMonitoringSetupDelayed, regionMonitoringResponseDelayed, geocodeFoundNoResult, geocodeFoundPartialResult
        case geocodeCanceled, deferredFailed, deferredNotUpdatingLocation, deferredAccuracyTooLow, deferredDistanceFiltered
        case deferredCanceled, rangingUnavailable, rangingFailure, promptDeclined, historicalLocationError
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { kCLErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public var errorDescription: String? { "The operation couldn’t be completed. (kCLErrorDomain error \(code.rawValue).)" }
    public var localizedDescription: String { errorDescription! }
    public static var locationUnknown: Code { .locationUnknown }
    public static var denied: Code { .denied }
    public static var network: Code { .network }
    public static var headingFailure: Code { .headingFailure }
    public static var regionMonitoringDenied: Code { .regionMonitoringDenied }
    public static var regionMonitoringFailure: Code { .regionMonitoringFailure }
    public static var geocodeFoundNoResult: Code { .geocodeFoundNoResult }
    public static var geocodeCanceled: Code { .geocodeCanceled }
    public static var promptDeclined: Code { .promptDeclined }
}
public func ~= (code: CLError.Code, error: Error) -> Bool { (error as? CLError)?.code == code }

// MARK: - CLLocation

open class CLFloor: NSObject, @unchecked Sendable { open var level: Int { 0 } }

open class CLLocationSourceInformation: NSObject, @unchecked Sendable {
    open private(set) var isSimulatedBySoftware: Bool
    open private(set) var isProducedByAccessory: Bool
    public init(softwareSimulationState: Bool, andExternalAccessoryState: Bool) {
        isSimulatedBySoftware = softwareSimulationState; isProducedByAccessory = andExternalAccessoryState
    }
}

open class CLLocation: NSObject, NSCopying, @unchecked Sendable {
    open private(set) var coordinate: CLLocationCoordinate2D
    open private(set) var altitude: CLLocationDistance
    open private(set) var ellipsoidalAltitude: CLLocationDistance
    open private(set) var horizontalAccuracy: CLLocationAccuracy
    open private(set) var verticalAccuracy: CLLocationAccuracy
    open private(set) var course: CLLocationDirection
    open private(set) var courseAccuracy: CLLocationDirectionAccuracy
    open private(set) var speed: CLLocationSpeed
    open private(set) var speedAccuracy: CLLocationSpeedAccuracy
    open private(set) var timestamp: Date
    open var floor: CLFloor? { nil }
    open private(set) var sourceInformation: CLLocationSourceInformation?

    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        altitude = 0; ellipsoidalAltitude = 0; horizontalAccuracy = 0; verticalAccuracy = -1
        course = -1; courseAccuracy = -1; speed = -1; speedAccuracy = -1; timestamp = Date()
    }
    public init(coordinate: CLLocationCoordinate2D, altitude: CLLocationDistance, horizontalAccuracy hAccuracy: CLLocationAccuracy,
                verticalAccuracy vAccuracy: CLLocationAccuracy, timestamp: Date) {
        self.coordinate = coordinate; self.altitude = altitude; ellipsoidalAltitude = altitude
        horizontalAccuracy = hAccuracy; verticalAccuracy = vAccuracy
        course = -1; courseAccuracy = -1; speed = -1; speedAccuracy = -1; self.timestamp = timestamp
    }
    public init(coordinate: CLLocationCoordinate2D, altitude: CLLocationDistance, horizontalAccuracy hAccuracy: CLLocationAccuracy,
                verticalAccuracy vAccuracy: CLLocationAccuracy, course: CLLocationDirection, speed: CLLocationSpeed, timestamp: Date) {
        self.coordinate = coordinate; self.altitude = altitude; ellipsoidalAltitude = altitude
        horizontalAccuracy = hAccuracy; verticalAccuracy = vAccuracy
        self.course = course; courseAccuracy = -1; self.speed = speed; speedAccuracy = -1; self.timestamp = timestamp
    }
    public init(coordinate: CLLocationCoordinate2D, altitude: CLLocationDistance, horizontalAccuracy hAccuracy: CLLocationAccuracy,
                verticalAccuracy vAccuracy: CLLocationAccuracy, course: CLLocationDirection, courseAccuracy: CLLocationDirectionAccuracy,
                speed: CLLocationSpeed, speedAccuracy: CLLocationSpeedAccuracy, timestamp: Date) {
        self.coordinate = coordinate; self.altitude = altitude; ellipsoidalAltitude = altitude
        horizontalAccuracy = hAccuracy; verticalAccuracy = vAccuracy
        self.course = course; self.courseAccuracy = courseAccuracy; self.speed = speed; self.speedAccuracy = speedAccuracy; self.timestamp = timestamp
    }
    public convenience init(coordinate: CLLocationCoordinate2D, altitude: CLLocationDistance, horizontalAccuracy hAccuracy: CLLocationAccuracy,
                            verticalAccuracy vAccuracy: CLLocationAccuracy, course: CLLocationDirection, courseAccuracy: CLLocationDirectionAccuracy,
                            speed: CLLocationSpeed, speedAccuracy: CLLocationSpeedAccuracy, timestamp: Date, sourceInfo: CLLocationSourceInformation) {
        self.init(coordinate: coordinate, altitude: altitude, horizontalAccuracy: hAccuracy, verticalAccuracy: vAccuracy, course: course,
                  courseAccuracy: courseAccuracy, speed: speed, speedAccuracy: speedAccuracy, timestamp: timestamp)
        sourceInformation = sourceInfo
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }

    /// great-circle distance in meters (haversine on the WGS-84 mean radius)
    open func distance(from location: CLLocation) -> CLLocationDistance {
        _CLGeo.distance(coordinate, location.coordinate)
    }
    @available(*, deprecated, renamed: "distance(from:)")
    open func getDistanceFrom(_ location: CLLocation) -> CLLocationDistance { distance(from: location) }

    open override var description: String {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .long
        return String(format: "<%+.8f,%+.8f> +/- %.2fm (speed %.2f mps / course %.2f) @ %@", coordinate.latitude, coordinate.longitude,
                      horizontalAccuracy, speed, course, f.string(from: timestamp))
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? CLLocation else { return false }
        return o.coordinate.latitude == coordinate.latitude && o.coordinate.longitude == coordinate.longitude && o.timestamp == timestamp
    }
    open override var hash: Int { coordinate.latitude.hashValue ^ coordinate.longitude.hashValue }
}

open class CLHeading: NSObject, @unchecked Sendable {
    open private(set) var magneticHeading: CLLocationDirection = -1
    open private(set) var trueHeading: CLLocationDirection = -1
    open private(set) var headingAccuracy: CLLocationDirection = -1
    open private(set) var x: CLHeadingComponentValue = 0
    open private(set) var y: CLHeadingComponentValue = 0
    open private(set) var z: CLHeadingComponentValue = 0
    open private(set) var timestamp = Date()
}

open class CLVisit: NSObject, @unchecked Sendable {
    open private(set) var arrivalDate = Date.distantPast
    open private(set) var departureDate = Date.distantFuture
    open private(set) var coordinate = kCLLocationCoordinate2DInvalid
    open private(set) var horizontalAccuracy: CLLocationAccuracy = -1
}

// MARK: - Regions

open class CLRegion: NSObject, NSCopying, @unchecked Sendable {
    open private(set) var identifier: String
    open var notifyOnEntry = true
    open var notifyOnExit = true
    init(identifier: String) { self.identifier = identifier }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }
    func _contains(_ c: CLLocationCoordinate2D) -> Bool { false }
}

open class CLCircularRegion: CLRegion, @unchecked Sendable {
    open private(set) var center: CLLocationCoordinate2D
    open private(set) var radius: CLLocationDistance
    public init(center: CLLocationCoordinate2D, radius: CLLocationDistance, identifier: String) {
        self.center = center; self.radius = radius
        super.init(identifier: identifier)
    }
    open func contains(_ coordinate: CLLocationCoordinate2D) -> Bool { _CLGeo.distance(center, coordinate) <= radius }
    override func _contains(_ c: CLLocationCoordinate2D) -> Bool { contains(c) }
    open override var description: String {
        String(format: "CLCircularRegion (identifier:'%@', center:<%+.8f,%+.8f>, radius:%.2f)", identifier, center.latitude, center.longitude, radius)
    }
}

/// iBeacon regions exist so apps compile; the simulated device has no Bluetooth LE, so ranging is unavailable (like the Simulator)
open class CLBeaconRegion: CLRegion, @unchecked Sendable {
    open private(set) var uuid: UUID
    open private(set) var major: NSNumber?
    open private(set) var minor: NSNumber?
    open var notifyEntryStateOnDisplay = false
    public init(uuid: UUID, identifier: String) { self.uuid = uuid; super.init(identifier: identifier) }
    public init(uuid: UUID, major: UInt16, identifier: String) { self.uuid = uuid; self.major = NSNumber(value: major); super.init(identifier: identifier) }
    public init(uuid: UUID, major: UInt16, minor: UInt16, identifier: String) {
        self.uuid = uuid; self.major = NSNumber(value: major); self.minor = NSNumber(value: minor); super.init(identifier: identifier)
    }
}

enum _CLGeo {
    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6_371_008.8, rad = Double.pi / 180
        let dLat = (b.latitude - a.latitude) * rad, dLon = (b.longitude - a.longitude) * rad
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(a.latitude * rad) * cos(b.latitude * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }
    /// initial bearing a -> b in degrees
    static func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let rad = Double.pi / 180
        let y = sin((b.longitude - a.longitude) * rad) * cos(b.latitude * rad)
        let x = cos(a.latitude * rad) * sin(b.latitude * rad) - sin(a.latitude * rad) * cos(b.latitude * rad) * cos((b.longitude - a.longitude) * rad)
        let d = atan2(y, x) / rad
        return d < 0 ? d + 360 : d
    }
}
