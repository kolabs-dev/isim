// isim CoreLocation for Objective-C (sdk-src/Frameworks/CoreLocation): the classes carry Apple's Objective-C names and
// these members Apple's selectors. CLLocationCoordinate2D is a Swift struct here, so the members that take or return
// one are in CoreLocation.m, over the _isim_ members below that pass its components. CLLocationManagerDelegate is an
// @objc protocol with Apple's selectors, so Objective-C delegates are used as they are.
import UIKit

extension CLLocationManager {
    @objc(delegate) var _objc_delegate: CLLocationManagerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(desiredAccuracy) var _objc_desiredAccuracy: Double { get { desiredAccuracy } set { desiredAccuracy = newValue } }
    @objc(distanceFilter) var _objc_distanceFilter: Double { get { distanceFilter } set { distanceFilter = newValue } }
    @objc(activityType) var _objc_activityType: CLActivityType { get { activityType } set { activityType = newValue } }
    @objc(pausesLocationUpdatesAutomatically) var _objc_pauses: Bool {
        get { pausesLocationUpdatesAutomatically } set { pausesLocationUpdatesAutomatically = newValue }
    }
    @objc(allowsBackgroundLocationUpdates) var _objc_allowsBackground: Bool {
        get { allowsBackgroundLocationUpdates } set { allowsBackgroundLocationUpdates = newValue }
    }
    @objc(showsBackgroundLocationIndicator) var _objc_showsIndicator: Bool {
        get { showsBackgroundLocationIndicator } set { showsBackgroundLocationIndicator = newValue }
    }
    @objc(headingFilter) var _objc_headingFilter: Double { get { headingFilter } set { headingFilter = newValue } }
    @objc(heading) var _objc_heading: CLHeading? { heading }
    @objc(location) var _objc_location: CLLocation? { location }
    @objc(monitoredRegions) var _objc_monitoredRegions: Set<CLRegion> { monitoredRegions }
    @objc(maximumRegionMonitoringDistance) var _objc_maximumRegionMonitoringDistance: Double { maximumRegionMonitoringDistance }
    @objc(authorizationStatus) var _objc_authorizationStatus: CLAuthorizationStatus { authorizationStatus }
    @available(iOS, deprecated: 14.0, message: "Use the authorizationStatus instance property")   // as Apple's
    @objc(authorizationStatus) class func _objc_classAuthorizationStatus() -> CLAuthorizationStatus { authorizationStatus() }
    @objc(accuracyAuthorization) var _objc_accuracyAuthorization: CLAccuracyAuthorization { accuracyAuthorization }
    @objc(locationServicesEnabled) class func _objc_locationServicesEnabled() -> Bool { locationServicesEnabled() }
    @objc(headingAvailable) class func _objc_headingAvailable() -> Bool { headingAvailable() }
    @objc(significantLocationChangeMonitoringAvailable) class func _objc_significantAvailable() -> Bool {
        significantLocationChangeMonitoringAvailable()
    }
    @objc(isMonitoringAvailableForClass:) class func _objc_isMonitoringAvailable(_ cls: AnyClass) -> Bool { isMonitoringAvailable(for: cls) }
    @objc(isRangingAvailable) class func _objc_isRangingAvailable() -> Bool { isRangingAvailable() }
    @objc(requestWhenInUseAuthorization) func _objc_requestWhenInUse() { requestWhenInUseAuthorization() }
    @objc(requestAlwaysAuthorization) func _objc_requestAlways() { requestAlwaysAuthorization() }
    @objc(requestTemporaryFullAccuracyAuthorizationWithPurposeKey:completion:)
    func _objc_requestTemporaryFullAccuracy(_ key: String, completion: (@convention(block) (NSError?) -> Void)?) {
        requestTemporaryFullAccuracyAuthorization(withPurposeKey: key) { e in completion?(e.map { $0 as NSError }) }
    }
    @objc(startUpdatingLocation) func _objc_startUpdatingLocation() { startUpdatingLocation() }
    @objc(stopUpdatingLocation) func _objc_stopUpdatingLocation() { stopUpdatingLocation() }
    @objc(requestLocation) func _objc_requestLocation() { requestLocation() }
    @objc(startMonitoringSignificantLocationChanges) func _objc_startSignificant() { startMonitoringSignificantLocationChanges() }
    @objc(stopMonitoringSignificantLocationChanges) func _objc_stopSignificant() { stopMonitoringSignificantLocationChanges() }
    @objc(startUpdatingHeading) func _objc_startUpdatingHeading() { startUpdatingHeading() }
    @objc(stopUpdatingHeading) func _objc_stopUpdatingHeading() { stopUpdatingHeading() }
    @objc(startMonitoringVisits) func _objc_startMonitoringVisits() { startMonitoringVisits() }
    @objc(stopMonitoringVisits) func _objc_stopMonitoringVisits() { stopMonitoringVisits() }
    @objc(startMonitoringForRegion:) func _objc_startMonitoring(_ region: CLRegion) { startMonitoring(for: region) }
    @objc(stopMonitoringForRegion:) func _objc_stopMonitoring(_ region: CLRegion) { stopMonitoring(for: region) }
    @objc(requestStateForRegion:) func _objc_requestState(_ region: CLRegion) { requestState(for: region) }
}

extension CLLocation {
    @objc(initWithLatitude:longitude:) convenience init(_objcLatitude latitude: Double, longitude: Double) {
        self.init(latitude: latitude, longitude: longitude)
    }
    @objc(_isim_initWithLatitude:longitude:altitude:horizontalAccuracy:verticalAccuracy:course:speed:timestamp:)
    convenience init(_isimLatitude latitude: Double, longitude: Double, altitude: Double, horizontalAccuracy: Double, verticalAccuracy: Double,
                     course: Double, speed: Double, timestamp: Date) {
        self.init(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), altitude: altitude,
                  horizontalAccuracy: horizontalAccuracy, verticalAccuracy: verticalAccuracy, course: course, speed: speed, timestamp: timestamp)
    }
    @objc(_isim_latitude) var _isim_latitude: Double { coordinate.latitude }
    @objc(_isim_longitude) var _isim_longitude: Double { coordinate.longitude }
    @objc(altitude) var _objc_altitude: Double { altitude }
    @objc(ellipsoidalAltitude) var _objc_ellipsoidalAltitude: Double { ellipsoidalAltitude }
    @objc(horizontalAccuracy) var _objc_horizontalAccuracy: Double { horizontalAccuracy }
    @objc(verticalAccuracy) var _objc_verticalAccuracy: Double { verticalAccuracy }
    @objc(course) var _objc_course: Double { course }
    @objc(courseAccuracy) var _objc_courseAccuracy: Double { courseAccuracy }
    @objc(speed) var _objc_speed: Double { speed }
    @objc(speedAccuracy) var _objc_speedAccuracy: Double { speedAccuracy }
    @objc(timestamp) var _objc_timestamp: Date { timestamp }
    @objc(floor) var _objc_floor: CLFloor? { floor }
    @objc(distanceFromLocation:) func _objc_distance(_ location: CLLocation) -> Double { distance(from: location) }
}

extension CLFloor {
    @objc(level) var _objc_level: Int { level }
}

extension CLHeading {
    @objc(magneticHeading) var _objc_magneticHeading: Double { magneticHeading }
    @objc(trueHeading) var _objc_trueHeading: Double { trueHeading }
    @objc(headingAccuracy) var _objc_headingAccuracy: Double { headingAccuracy }
    @objc(x) var _objc_x: Double { x }
    @objc(y) var _objc_y: Double { y }
    @objc(z) var _objc_z: Double { z }
    @objc(timestamp) var _objc_timestamp: Date { timestamp }
}

extension CLVisit {
    @objc(arrivalDate) var _objc_arrivalDate: Date { arrivalDate }
    @objc(departureDate) var _objc_departureDate: Date { departureDate }
    @objc(_isim_latitude) var _isim_latitude: Double { coordinate.latitude }
    @objc(_isim_longitude) var _isim_longitude: Double { coordinate.longitude }
    @objc(horizontalAccuracy) var _objc_horizontalAccuracy: Double { horizontalAccuracy }
}

extension CLRegion {
    @objc(identifier) var _objc_identifier: String { identifier }
    @objc(notifyOnEntry) var _objc_notifyOnEntry: Bool { get { notifyOnEntry } set { notifyOnEntry = newValue } }
    @objc(notifyOnExit) var _objc_notifyOnExit: Bool { get { notifyOnExit } set { notifyOnExit = newValue } }
}

extension CLCircularRegion {
    @objc(_isim_initWithLatitude:longitude:radius:identifier:)
    convenience init(_isimLatitude latitude: Double, longitude: Double, radius: Double, identifier: String) {
        self.init(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier)
    }
    @objc(_isim_latitude) var _isim_latitude: Double { center.latitude }
    @objc(_isim_longitude) var _isim_longitude: Double { center.longitude }
    @objc(radius) var _objc_radius: Double { radius }
    @objc(_isim_containsLatitude:longitude:) func _isim_contains(_ latitude: Double, longitude: Double) -> Bool {
        contains(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }
}

extension CLPlacemark {
    @objc(initWithPlacemark:) convenience init(_objcPlacemark p: CLPlacemark) { self.init(placemark: p) }
    @objc(location) var _objc_location: CLLocation? { location }
    @objc(region) var _objc_region: CLRegion? { region }
    @objc(timeZone) var _objc_timeZone: TimeZone? { timeZone }
    @objc(name) var _objc_name: String? { name }
    @objc(thoroughfare) var _objc_thoroughfare: String? { thoroughfare }
    @objc(subThoroughfare) var _objc_subThoroughfare: String? { subThoroughfare }
    @objc(locality) var _objc_locality: String? { locality }
    @objc(subLocality) var _objc_subLocality: String? { subLocality }
    @objc(administrativeArea) var _objc_administrativeArea: String? { administrativeArea }
    @objc(subAdministrativeArea) var _objc_subAdministrativeArea: String? { subAdministrativeArea }
    @objc(postalCode) var _objc_postalCode: String? { postalCode }
    @objc(ISOcountryCode) var _objc_isoCountryCode: String? { isoCountryCode }
    @objc(country) var _objc_country: String? { country }
    @objc(inlandWater) var _objc_inlandWater: String? { inlandWater }
    @objc(ocean) var _objc_ocean: String? { ocean }
    @objc(areasOfInterest) var _objc_areasOfInterest: [String]? { areasOfInterest }
}

extension CLGeocoder {
    @objc(isGeocoding) var _objc_isGeocoding: Bool { isGeocoding }
    @objc(reverseGeocodeLocation:completionHandler:)
    func _objc_reverse(_ location: CLLocation, completionHandler: @escaping @convention(block) ([CLPlacemark]?, NSError?) -> Void) {
        reverseGeocodeLocation(location) { p, e in completionHandler(p, e.map { $0 as NSError }) }
    }
    @objc(reverseGeocodeLocation:preferredLocale:completionHandler:)
    func _objc_reverse(_ location: CLLocation, preferredLocale locale: Locale?,
                       completionHandler: @escaping @convention(block) ([CLPlacemark]?, NSError?) -> Void) {
        reverseGeocodeLocation(location, preferredLocale: locale) { p, e in completionHandler(p, e.map { $0 as NSError }) }
    }
    @objc(geocodeAddressString:completionHandler:)
    func _objc_geocode(_ address: String, completionHandler: @escaping @convention(block) ([CLPlacemark]?, NSError?) -> Void) {
        geocodeAddressString(address) { p, e in completionHandler(p, e.map { $0 as NSError }) }
    }
    @objc(geocodeAddressString:inRegion:completionHandler:)
    func _objc_geocode(_ address: String, inRegion region: CLRegion?,
                       completionHandler: @escaping @convention(block) ([CLPlacemark]?, NSError?) -> Void) {
        geocodeAddressString(address, in: region) { p, e in completionHandler(p, e.map { $0 as NSError }) }
    }
    @objc(cancelGeocode) func _objc_cancel() { cancelGeocode() }
}

// isim-private: the simulated location as the app sees it (UserNotifications' location triggers read it)
extension CLLocationManager {
    @objc(_isim_simulatedLocation) class func _isim_simulatedLocation() -> CLLocation? { _CLSim.shared.current() }
}
