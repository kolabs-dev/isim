// isim CarPlay: navigation apps (the map template, trips and route choices, navigation sessions and maneuvers, alerts,
// panels, multi-stop routes).
import CoreLocation
import Foundation
import MapKit
import UIKit

extension CPMapTemplate { public typealias PanDirection = CPPanDirection }

@objc(CPMapButton)
open class CPMapButton: NSObject, NSSecureCoding {
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    var _isHidden: Bool = false
    @objc open var isHidden: Bool {
        @objc(isHidden) get { _isHidden }
        @objc(setHidden:) set { _isHidden = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var image: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var focusedImage: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    var _handler: ((CPMapButton) -> Void)?
    @objc public init(handler: ((CPMapButton) -> Void)?) { _handler = handler; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(isEnabled, forKey: "enabled"); c.encode(isHidden, forKey: "hidden") }
    public required init?(coder c: NSCoder) {
        _isEnabled = c.containsValue(forKey: "enabled") ? c.decodeBool(forKey: "enabled") : true
        _isHidden = c.decodeBool(forKey: "hidden")
        super.init()
    }
    func _tap() { if isEnabled && !isHidden { _handler?(self) } }
}

// MARK: - estimates, route choices and trips

@objc(CPTravelEstimates)
open class CPTravelEstimates: NSObject, NSSecureCoding {
    @objc open private(set) var distanceRemaining: Measurement<UnitLength>
    @objc open private(set) var distanceRemainingToDisplay: Measurement<UnitLength>
    @objc open private(set) var timeRemaining: TimeInterval
    @objc open private(set) var routeDetails: [CPRouteDetail] = []
    @objc public init(distanceRemaining: Measurement<UnitLength>, distanceRemainingToDisplay: Measurement<UnitLength>, timeRemaining: TimeInterval) {
        self.distanceRemaining = distanceRemaining; self.distanceRemainingToDisplay = distanceRemainingToDisplay; self.timeRemaining = timeRemaining
        super.init()
    }
    @objc public convenience init(distanceRemaining: Measurement<UnitLength>, timeRemaining: TimeInterval) {
        self.init(distanceRemaining: distanceRemaining, distanceRemainingToDisplay: distanceRemaining, timeRemaining: timeRemaining)
    }
    @objc public convenience init(distanceRemaining: Measurement<UnitLength>, distanceRemainingToDisplay: Measurement<UnitLength>, timeRemaining: TimeInterval, routeDetails: [CPRouteDetail]) {
        self.init(distanceRemaining: distanceRemaining, distanceRemainingToDisplay: distanceRemainingToDisplay, timeRemaining: timeRemaining)
        self.routeDetails = routeDetails
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(distanceRemaining.converted(to: .meters).value, forKey: "distance")
        c.encode(distanceRemainingToDisplay.converted(to: .meters).value, forKey: "display"); c.encode(timeRemaining, forKey: "time")
    }
    public required init?(coder c: NSCoder) {
        distanceRemaining = Measurement(value: c.decodeDouble(forKey: "distance"), unit: .meters)
        distanceRemainingToDisplay = Measurement(value: c.decodeDouble(forKey: "display"), unit: .meters)
        timeRemaining = c.decodeDouble(forKey: "time")
        super.init()
    }
    /// "12 min · 8.4 km" (the car's units: the measurement's own)
    var _text: String {
        let m = Int((timeRemaining / 60).rounded())
        let time = m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(max(m, 0)) min"
        let d = distanceRemainingToDisplay
        let dist = d.unit == UnitLength.miles || d.unit == UnitLength.feet || d.unit == UnitLength.yards
            ? String(format: "%.1f mi", d.converted(to: .miles).value) : (d.converted(to: .meters).value < 1000
                ? String(format: "%.0f m", d.converted(to: .meters).value) : String(format: "%.1f km", d.converted(to: .kilometers).value))
        return "\(time) · \(dist)"
    }
}

@objc(CPRouteChoice)
open class CPRouteChoice: NSObject, NSCopying, NSSecureCoding {
    @objc open private(set) var summaryVariants: [String]
    @objc open private(set) var additionalInformationVariants: [String]?
    @objc open private(set) var selectionSummaryVariants: [String]?
    @objc open private(set) var travelEstimates: CPTravelEstimates?
    @objc open var userInfo: Any?
    @objc public init(summaryVariants: [String], additionalInformationVariants: [String], selectionSummaryVariants: [String]) {
        self.summaryVariants = summaryVariants; self.additionalInformationVariants = additionalInformationVariants; self.selectionSummaryVariants = selectionSummaryVariants
        super.init()
    }
    @objc public convenience init(summaryVariants: [String], additionalInformationVariants: [String], selectionSummaryVariants: [String], travelEstimates: CPTravelEstimates?) {
        self.init(summaryVariants: summaryVariants, additionalInformationVariants: additionalInformationVariants, selectionSummaryVariants: selectionSummaryVariants)
        self.travelEstimates = travelEstimates
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let r = CPRouteChoice(summaryVariants: summaryVariants, additionalInformationVariants: additionalInformationVariants ?? [],
                              selectionSummaryVariants: selectionSummaryVariants ?? [], travelEstimates: travelEstimates)
        r.userInfo = userInfo
        return r
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(summaryVariants, forKey: "summary"); c.encode(additionalInformationVariants, forKey: "info"); c.encode(selectionSummaryVariants, forKey: "selection")
    }
    public required init?(coder c: NSCoder) {
        summaryVariants = _cpDecodeStrings(c, "summary")
        additionalInformationVariants = _cpDecodeStrings(c, "info"); selectionSummaryVariants = _cpDecodeStrings(c, "selection")
        super.init()
    }
}

extension CPLocationCoordinate3D {
    var _clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

@objc(CPNavigationWaypoint)
open class CPNavigationWaypoint: NSObject, NSSecureCoding {
    @objc open private(set) var centerPoint: CPLocationCoordinate3D
    @objc open private(set) var locationThreshold: Measurement<UnitLength>?
    @objc open private(set) var nameVariants: [String]
    @objc open private(set) var addressVariants: [String]
    @objc open var name: String? { nameVariants.first }
    @objc open var address: String? { addressVariants.first }
    @nonobjc public private(set) var entryPoints: [CPLocationCoordinate3D] {
        get { Array(_entryBuffer) }
        set { _entryBuffer.deallocate(); _entryBuffer = .allocate(capacity: newValue.count); _ = _entryBuffer.initialize(from: newValue) }
    }
    var _entryBuffer = UnsafeMutableBufferPointer<CPLocationCoordinate3D>.allocate(capacity: 0)
    // Objective-C: a C array and its count
    @objc(entryPoints) var _objcEntryPoints: UnsafeMutablePointer<CPLocationCoordinate3D>? { _entryBuffer.baseAddress }
    @objc var entryPointsCount: Int { _entryBuffer.count }
    deinit { _entryBuffer.deallocate() }
    @objc open private(set) var timeZone: TimeZone?
    init(_center: CPLocationCoordinate3D, threshold: Measurement<UnitLength>?, names: [String], addresses: [String], entries: [CPLocationCoordinate3D], timeZone: TimeZone?) {
        centerPoint = _center; locationThreshold = threshold; nameVariants = names; addressVariants = addresses; self.timeZone = timeZone
        super.init()
        entryPoints = entries
    }
    public convenience init(centerPoint: CPLocationCoordinate3D, locationThreshold: Measurement<UnitLength>?, name: String?, address: String?,
                            entryPoints: [CPLocationCoordinate3D], timeZone: TimeZone?) {
        self.init(_center: centerPoint, threshold: locationThreshold, names: name.map { [$0] } ?? [], addresses: address.map { [$0] } ?? [], entries: entryPoints, timeZone: timeZone)
    }
    public convenience init(centerPoint: CPLocationCoordinate3D, locationThreshold: Measurement<UnitLength>?, nameVariants: [String], addressVariants: [String],
                            entryPoints: [CPLocationCoordinate3D], timeZone: TimeZone?) {
        self.init(_center: centerPoint, threshold: locationThreshold, names: nameVariants, addresses: addressVariants, entries: entryPoints, timeZone: timeZone)
    }
    @objc(initWithCenterPoint:locationThreshold:name:address:entryPoints:entryPointsCount:timeZone:)
    convenience init(_objcCenterPoint centerPoint: CPLocationCoordinate3D, locationThreshold: Measurement<UnitLength>?, name: String?, address: String?,
                            entryPoints: UnsafePointer<CPLocationCoordinate3D>?, entryPointsCount: Int, timeZone: TimeZone?) {
        self.init(centerPoint: centerPoint, locationThreshold: locationThreshold, name: name, address: address,
                  entryPoints: entryPoints.map { Array(UnsafeBufferPointer(start: $0, count: entryPointsCount)) } ?? [], timeZone: timeZone)
    }
    @objc(initWithMapItem:locationThreshold:entryPoints:entryPointsCount:)
    convenience init(_objcMapItem mapItem: MKMapItem, locationThreshold: Measurement<UnitLength>?, entryPoints: UnsafePointer<CPLocationCoordinate3D>?, entryPointsCount: Int) {
        self.init(mapItem: mapItem, locationThreshold: locationThreshold, entryPoints: entryPoints.map { Array(UnsafeBufferPointer(start: $0, count: entryPointsCount)) } ?? [])
    }
    public convenience init(mapItem: MKMapItem, locationThreshold: Measurement<UnitLength>?, entryPoints: [CPLocationCoordinate3D]) {
        let c = mapItem.placemark.coordinate
        self.init(_center: CPLocationCoordinate3D(latitude: c.latitude, longitude: c.longitude, altitude: 0), threshold: locationThreshold,
                  names: mapItem.name.map { [$0] } ?? [], addresses: [], entries: entryPoints, timeZone: mapItem.timeZone)
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(centerPoint.latitude, forKey: "lat"); c.encode(centerPoint.longitude, forKey: "lon"); c.encode(centerPoint.altitude, forKey: "alt")
        c.encode(nameVariants, forKey: "names"); c.encode(addressVariants, forKey: "addresses")
    }
    public required init?(coder c: NSCoder) {
        centerPoint = CPLocationCoordinate3D(latitude: c.decodeDouble(forKey: "lat"), longitude: c.decodeDouble(forKey: "lon"), altitude: c.decodeDouble(forKey: "alt"))
        nameVariants = _cpDecodeStrings(c, "names"); addressVariants = _cpDecodeStrings(c, "addresses")
        super.init()
    }
}

@objc(CPTrip)
open class CPTrip: NSObject, NSSecureCoding {
    @objc open private(set) var origin: MKMapItem
    @objc open private(set) var destination: MKMapItem
    @objc open private(set) var routeChoices: [CPRouteChoice]
    @objc open var destinationNameVariants: [String]?
    @objc open var userInfo: Any?
    @objc open private(set) var originWaypoint: CPNavigationWaypoint
    @objc open private(set) var destinationWaypoint: CPNavigationWaypoint
    @objc open var hasShareableDestination: Bool = false
    @objc open var routeSegmentsAvailableForRegion: Bool = false
    @objc public init(origin: MKMapItem, destination: MKMapItem, routeChoices: [CPRouteChoice]) {
        self.origin = origin; self.destination = destination; self.routeChoices = routeChoices
        originWaypoint = CPNavigationWaypoint(mapItem: origin, locationThreshold: nil, entryPoints: [])
        destinationWaypoint = CPNavigationWaypoint(mapItem: destination, locationThreshold: nil, entryPoints: [])
        super.init()
    }
    @objc public init(originWaypoint: CPNavigationWaypoint, destinationWaypoint: CPNavigationWaypoint, routeChoices: [CPRouteChoice]) {
        self.originWaypoint = originWaypoint; self.destinationWaypoint = destinationWaypoint; self.routeChoices = routeChoices
        let item = { (w: CPNavigationWaypoint) -> MKMapItem in
            let m = MKMapItem(placemark: MKPlacemark(coordinate: w.centerPoint._clCoordinate)); m.name = w.name; return m
        }
        origin = item(originWaypoint); destination = item(destinationWaypoint)
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(originWaypoint, forKey: "origin"); c.encode(destinationWaypoint, forKey: "destination"); c.encode(routeChoices, forKey: "routes") }
    public required init?(coder c: NSCoder) {
        guard let o = c.decodeObject(of: CPNavigationWaypoint.self, forKey: "origin"), let d = c.decodeObject(of: CPNavigationWaypoint.self, forKey: "destination") else { return nil }
        originWaypoint = o; destinationWaypoint = d
        routeChoices = (c.decodeObject(of: [NSArray.self, CPRouteChoice.self], forKey: "routes") as? [CPRouteChoice]) ?? []
        origin = MKMapItem(placemark: MKPlacemark(coordinate: o.centerPoint._clCoordinate))
        destination = MKMapItem(placemark: MKPlacemark(coordinate: d.centerPoint._clCoordinate))
        super.init()
    }
    var _destinationName: String { destinationNameVariants?.first ?? destination.name ?? destinationWaypoint.name ?? "Destination" }
}

@objc(CPTripPreviewTextConfiguration)
open class CPTripPreviewTextConfiguration: NSObject, NSSecureCoding {
    @objc open private(set) var startButtonTitle: String?
    @objc open private(set) var additionalRoutesButtonTitle: String?
    @objc open private(set) var overviewButtonTitle: String?
    @objc public init(startButtonTitle: String?, additionalRoutesButtonTitle: String?, overviewButtonTitle: String?) {
        self.startButtonTitle = startButtonTitle; self.additionalRoutesButtonTitle = additionalRoutesButtonTitle; self.overviewButtonTitle = overviewButtonTitle
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(startButtonTitle, forKey: "start"); c.encode(additionalRoutesButtonTitle, forKey: "routes"); c.encode(overviewButtonTitle, forKey: "overview") }
    public required init?(coder c: NSCoder) {
        startButtonTitle = c.decodeObject(of: NSString.self, forKey: "start") as String?
        additionalRoutesButtonTitle = c.decodeObject(of: NSString.self, forKey: "routes") as String?
        overviewButtonTitle = c.decodeObject(of: NSString.self, forKey: "overview") as String?
        super.init()
    }
}

// MARK: - maneuvers and lanes

@objc(CPLane)
open class CPLane: NSObject, NSCopying, NSSecureCoding {
    @objc open private(set) var status: CPLaneStatus
    @objc open private(set) var angles: [Measurement<UnitAngle>]
    @objc open private(set) var highlightedAngle: Measurement<UnitAngle>?
    @objc open var primaryAngle: Measurement<UnitAngle> { highlightedAngle ?? angles.first ?? Measurement(value: 0, unit: .degrees) }
    @objc open var secondaryAngles: [Measurement<UnitAngle>] { angles.filter { $0 != primaryAngle } }
    @objc public override init() { status = .notGood; angles = []; super.init() }
    @objc public init(angles: [Measurement<UnitAngle>]) { status = .notGood; self.angles = angles; super.init() }
    @objc public init(angles: [Measurement<UnitAngle>], highlightedAngle: Measurement<UnitAngle>, isPreferred: Bool) {
        status = isPreferred ? .preferred : .good; self.angles = angles; self.highlightedAngle = highlightedAngle
        super.init()
    }
    public func copy(with zone: NSZone? = nil) -> Any {
        let l = CPLane(angles: angles); l.status = status; l.highlightedAngle = highlightedAngle; return l
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(status.rawValue, forKey: "status"); c.encode(angles.map { $0.converted(to: .degrees).value }, forKey: "angles") }
    public required init?(coder c: NSCoder) {
        status = .init(rawValue: c.decodeInteger(forKey: "status")) ?? .notGood
        angles = ((c.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "angles") as? [Double]) ?? []).map { Measurement(value: $0, unit: .degrees) }
        super.init()
    }
}

@objc(CPLaneGuidance)
open class CPLaneGuidance: NSObject, NSCopying, NSSecureCoding {
    @objc open var instructionVariants: [String] = []
    @objc open var lanes: [CPLane] = []
    @objc public override init() { super.init() }
    public func copy(with zone: NSZone? = nil) -> Any { let g = CPLaneGuidance(); g.instructionVariants = instructionVariants; g.lanes = lanes; return g }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(instructionVariants, forKey: "instructions"); c.encode(lanes, forKey: "lanes") }
    public required init?(coder c: NSCoder) {
        instructionVariants = _cpDecodeStrings(c, "instructions")
        lanes = (c.decodeObject(of: [NSArray.self, CPLane.self], forKey: "lanes") as? [CPLane]) ?? []
        super.init()
    }
}

@objc(CPManeuver)
open class CPManeuver: NSObject, NSCopying, NSSecureCoding {
    @objc open var instructionVariants: [String] = []
    @objc open var dashboardInstructionVariants: [String] = []
    @objc open var notificationInstructionVariants: [String] = []
    @objc open var attributedInstructionVariants: [NSAttributedString] = []
    @objc open var dashboardAttributedInstructionVariants: [NSAttributedString] = []
    @objc open var notificationAttributedInstructionVariants: [NSAttributedString] = []
    @objc open var initialTravelEstimates: CPTravelEstimates?
    @objc open var symbolImage: UIImage?
    @objc open var dashboardSymbolImage: UIImage?
    @objc open var notificationSymbolImage: UIImage?
    @objc open var symbolSet: CPImageSet?
    @objc open var junctionImage: UIImage?
    @objc open var dashboardJunctionImage: UIImage?
    @objc open var junctionType: CPJunctionType = .intersection
    @objc open var junctionExitAngle: Measurement<UnitAngle>?
    @objc open var junctionElementAngles: Set<Measurement<UnitAngle>>?
    @objc open var maneuverType: CPManeuverType = .noTurn
    @objc open var roadFollowingManeuverVariants: [String]?
    @objc open var linkedLaneGuidance: CPLaneGuidance = CPLaneGuidance()
    @objc open var highwayExitLabel: String = ""
    @objc open var trafficSide: CPTrafficSide = .right
    @objc open var cardBackgroundColor: UIColor?
    @objc open var userInfo: Any?
    @objc public override init() { super.init() }
    public func copy(with zone: NSZone? = nil) -> Any {
        let m = CPManeuver()
        m.instructionVariants = instructionVariants; m.dashboardInstructionVariants = dashboardInstructionVariants
        m.notificationInstructionVariants = notificationInstructionVariants; m.attributedInstructionVariants = attributedInstructionVariants
        m.initialTravelEstimates = initialTravelEstimates; m.symbolImage = symbolImage; m.symbolSet = symbolSet; m.junctionImage = junctionImage
        m.junctionType = junctionType; m.maneuverType = maneuverType; m.highwayExitLabel = highwayExitLabel; m.trafficSide = trafficSide
        m.cardBackgroundColor = cardBackgroundColor; m.userInfo = userInfo
        return m
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(instructionVariants, forKey: "instructions"); c.encode(maneuverType.rawValue, forKey: "type"); c.encode(initialTravelEstimates, forKey: "estimates")
    }
    public required init?(coder c: NSCoder) {
        instructionVariants = _cpDecodeStrings(c, "instructions")
        maneuverType = .init(rawValue: UInt(c.decodeInteger(forKey: "type"))) ?? .noTurn
        initialTravelEstimates = c.decodeObject(of: CPTravelEstimates.self, forKey: "estimates")
        super.init()
    }
    /// what the guidance card shows: the instruction, else the maneuver's name
    var _instruction: String { instructionVariants.first ?? attributedInstructionVariants.first?.string ?? _cpManeuverName(maneuverType) }
    /// the SF Symbol for its type (when it has no symbol image)
    var _symbolName: String {
        switch maneuverType {
        case .leftTurn, .leftTurnAtEnd, .sharpLeftTurn, .slightLeftTurn, .keepLeft, .highwayOffRampLeft, .changeHighwayLeft: return "arrow.up.left"
        case .rightTurn, .rightTurnAtEnd, .sharpRightTurn, .slightRightTurn, .keepRight, .highwayOffRampRight, .changeHighwayRight, .offRamp: return "arrow.up.right"
        case .uTurn, .uTurnWhenPossible, .uTurnAtRoundabout, .startRouteWithUTurn: return "arrow.uturn.down"
        case .arriveAtDestination, .arriveAtDestinationLeft, .arriveAtDestinationRight, .arriveEndOfDirections, .arriveEndOfNavigation: return "mappin.circle.fill"
        case .enterRoundabout, .exitRoundabout: return "arrow.clockwise"
        default: return "arrow.up"
        }
    }
}

@objc(CPRouteInformation)
open class CPRouteInformation: NSObject {
    @objc open private(set) var maneuvers: [CPManeuver]
    @objc open private(set) var laneGuidances: [CPLaneGuidance]
    @objc open private(set) var currentManeuvers: [CPManeuver]
    @objc open private(set) var currentLaneGuidance: CPLaneGuidance
    @objc open private(set) var tripTravelEstimates: CPTravelEstimates
    @objc open private(set) var maneuverTravelEstimates: CPTravelEstimates
    @objc public init(maneuvers: [CPManeuver], laneGuidances: [CPLaneGuidance], currentManeuvers: [CPManeuver], currentLaneGuidance: CPLaneGuidance,
                      tripTravelEstimates: CPTravelEstimates, maneuverTravelEstimates: CPTravelEstimates) {
        self.maneuvers = maneuvers; self.laneGuidances = laneGuidances; self.currentManeuvers = currentManeuvers; self.currentLaneGuidance = currentLaneGuidance
        self.tripTravelEstimates = tripTravelEstimates; self.maneuverTravelEstimates = maneuverTravelEstimates
        super.init()
    }
    @nonobjc public convenience init(maneuvers: [CPManeuver], laneGuidances: [CPLaneGuidance], currentManeuvers: [CPManeuver], currentLaneGuidance: CPLaneGuidance,
                                     trip: CPTravelEstimates, maneuverTravelEstimates: CPTravelEstimates) {
        self.init(maneuvers: maneuvers, laneGuidances: laneGuidances, currentManeuvers: currentManeuvers, currentLaneGuidance: currentLaneGuidance,
                  tripTravelEstimates: trip, maneuverTravelEstimates: maneuverTravelEstimates)
    }
}

// MARK: - route details and segments (iOS 26)

@objc(CPRouteDetail)
open class CPRouteDetail: NSObject, NSSecureCoding {
    var _symbol: String, _value: String
    @objc open var symbolTintColor: UIColor?
    init(_symbol: String, value: String) { self._symbol = _symbol; _value = value; super.init() }
    @objc public convenience init(symbolName: String, value: String) { self.init(_symbol: symbolName, value: value) }
    @objc public convenience init(info: String) { self.init(_symbol: "info.circle", value: info) }
    @objc public convenience init(warning: String) { self.init(_symbol: "exclamationmark.triangle", value: warning) }
    @objc public convenience init(parking: String) { self.init(_symbol: "parkingsign", value: parking) }
    @objc(initWithHOV:) public convenience init(HOV: String) { self.init(_symbol: "person.2", value: HOV) }
    @nonobjc public convenience init(hov: String) { self.init(HOV: hov) }
    @objc public convenience init(rating: Double) { self.init(_symbol: "star.fill", value: String(format: "%.1f", rating)) }
    @objc public convenience init(ecoScore: Double) { self.init(_symbol: "leaf", value: String(format: "%.0f", ecoScore)) }
    @objc public convenience init(batteryLevel: Double) { self.init(_symbol: "battery.75", value: String(format: "%.0f%%", batteryLevel * (batteryLevel <= 1 ? 100 : 1))) }
    @objc public convenience init(trafficLights: Int) { self.init(_symbol: "light.beacon.max", value: "\(trafficLights)") }
    @objc public convenience init(tollAmount: Double, locale: Locale) {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = locale
        self.init(_symbol: "dollarsign.circle", value: f.string(from: NSNumber(value: tollAmount)) ?? String(tollAmount))
    }
    @objc public convenience init(carbonFootprint: Measurement<UnitMass>) { self.init(_symbol: "carbon.dioxide.cloud", value: MeasurementFormatter().string(from: carbonFootprint)) }
    @objc public convenience init(emissions: Measurement<UnitMass>) { self.init(_symbol: "aqi.medium", value: MeasurementFormatter().string(from: emissions)) }
    @objc public convenience init(fuelEnergy: Measurement<UnitEnergy>) { self.init(_symbol: "fuelpump", value: MeasurementFormatter().string(from: fuelEnergy)) }
    @objc public convenience init(fuelLevel: Measurement<UnitVolume>) { self.init(_symbol: "fuelpump", value: MeasurementFormatter().string(from: fuelLevel)) }
    @objc public convenience init(fuelMass: Measurement<UnitMass>) { self.init(_symbol: "fuelpump", value: MeasurementFormatter().string(from: fuelMass)) }
    @objc public convenience init(kilowattHours: Measurement<UnitEnergy>) { self.init(_symbol: "bolt.car", value: MeasurementFormatter().string(from: kilowattHours)) }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(_symbol, forKey: "symbol"); c.encode(_value, forKey: "value") }
    public required init?(coder c: NSCoder) {
        _symbol = (c.decodeObject(of: NSString.self, forKey: "symbol") as String?) ?? "info.circle"
        _value = (c.decodeObject(of: NSString.self, forKey: "value") as String?) ?? ""
        super.init()
    }
}

@objc(CPRouteSegment)
open class CPRouteSegment: NSObject {
    @objc open private(set) var identifier = UUID()
    @objc open private(set) var origin: CPNavigationWaypoint
    @objc open private(set) var destination: CPNavigationWaypoint
    @objc open private(set) var maneuvers: [CPManeuver]
    @objc open private(set) var laneGuidances: [CPLaneGuidance]
    @objc open private(set) var currentManeuvers: [CPManeuver]
    @objc open private(set) var currentLaneGuidance: CPLaneGuidance
    @objc open private(set) var tripTravelEstimates: CPTravelEstimates
    @objc open private(set) var maneuverTravelEstimates: CPTravelEstimates
    @nonobjc public let coordinates: [CPLocationCoordinate3D]
    let _coordinateBuffer: UnsafeMutableBufferPointer<CPLocationCoordinate3D>
    @objc(coordinates) var _objcCoordinates: UnsafeMutablePointer<CPLocationCoordinate3D>? { _coordinateBuffer.baseAddress }
    @objc var coordinatesCount: Int { coordinates.count }
    deinit { _coordinateBuffer.deallocate() }
    public init(origin: CPNavigationWaypoint, destination: CPNavigationWaypoint, maneuvers: [CPManeuver], laneGuidances: [CPLaneGuidance],
                currentManeuvers: [CPManeuver], currentLaneGuidance: CPLaneGuidance, tripTravelEstimates: CPTravelEstimates,
                maneuverTravelEstimates: CPTravelEstimates, coordinates: [CPLocationCoordinate3D]) {
        self.origin = origin; self.destination = destination; self.maneuvers = maneuvers; self.laneGuidances = laneGuidances
        self.currentManeuvers = currentManeuvers; self.currentLaneGuidance = currentLaneGuidance; self.tripTravelEstimates = tripTravelEstimates
        self.maneuverTravelEstimates = maneuverTravelEstimates; self.coordinates = coordinates
        _coordinateBuffer = .allocate(capacity: coordinates.count); _ = _coordinateBuffer.initialize(from: coordinates)
        super.init()
    }
    @objc(initWithOrigin:destination:maneuvers:laneGuidances:currentManeuvers:currentLaneGuidance:tripTravelEstimates:maneuverTravelEstimates:coordinates:coordinatesCount:)
    convenience init(_objcOrigin origin: CPNavigationWaypoint, destination: CPNavigationWaypoint, maneuvers: [CPManeuver], laneGuidances: [CPLaneGuidance],
                            currentManeuvers: [CPManeuver], currentLaneGuidance: CPLaneGuidance, tripTravelEstimates: CPTravelEstimates,
                            maneuverTravelEstimates: CPTravelEstimates, coordinates: UnsafePointer<CPLocationCoordinate3D>?, coordinatesCount: Int) {
        self.init(origin: origin, destination: destination, maneuvers: maneuvers, laneGuidances: laneGuidances, currentManeuvers: currentManeuvers,
                  currentLaneGuidance: currentLaneGuidance, tripTravelEstimates: tripTravelEstimates, maneuverTravelEstimates: maneuverTravelEstimates,
                  coordinates: coordinates.map { Array(UnsafeBufferPointer(start: $0, count: coordinatesCount)) } ?? [])
    }
}

@objc(CPMapTemplateWaypoint)
open class CPMapTemplateWaypoint: NSObject, NSSecureCoding {
    @objc open private(set) var waypoint: CPNavigationWaypoint
    @objc open private(set) var travelEstimates: CPTravelEstimates
    @objc public init(waypoint: CPNavigationWaypoint, travelEstimates: CPTravelEstimates) { self.waypoint = waypoint; self.travelEstimates = travelEstimates; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(waypoint, forKey: "waypoint"); c.encode(travelEstimates, forKey: "estimates") }
    public required init?(coder c: NSCoder) {
        guard let w = c.decodeObject(of: CPNavigationWaypoint.self, forKey: "waypoint"), let e = c.decodeObject(of: CPTravelEstimates.self, forKey: "estimates") else { return nil }
        waypoint = w; travelEstimates = e
        super.init()
    }
}

@objc(CPMultiStopCardConfiguration)
open class CPMultiStopCardConfiguration: NSObject, NSSecureCoding {
    @objc open private(set) var title: String?
    @objc open private(set) var buttons: [CPTextButton]
    @objc open private(set) var image: UIImage?
    @objc public init(title: String?, buttons: [CPTextButton]) { self.title = title; self.buttons = buttons; super.init() }
    @objc public convenience init(title: String?, buttons: [CPTextButton], image: UIImage?) { self.init(title: title, buttons: buttons); self.image = image }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(title, forKey: "title") }
    public required init?(coder c: NSCoder) { title = c.decodeObject(of: NSString.self, forKey: "title") as String?; buttons = []; super.init() }
}

@objc(CPChargingStationConnection)
open class CPChargingStationConnection: NSObject, NSSecureCoding {
    @objc(CPChargingStationConnector) public enum Connector: Int, @unchecked Sendable { case j1772 = 0, ccs1, ccs2, chaDeMo, mennekes, gbtAC, gbtDC, nacsAC, nacsDC }
    @objc open private(set) var connector: CPChargingStationConnection.Connector
    @objc open private(set) var voltage: Measurement<UnitElectricPotentialDifference>
    @objc open private(set) var power: Measurement<UnitPower>
    @objc public init(connector: CPChargingStationConnection.Connector, voltage: Measurement<UnitElectricPotentialDifference>, power: Measurement<UnitPower>) {
        self.connector = connector; self.voltage = voltage; self.power = power
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(connector.rawValue, forKey: "connector"); c.encode(voltage.converted(to: .volts).value, forKey: "volts"); c.encode(power.converted(to: .kilowatts).value, forKey: "kw")
    }
    public required init?(coder c: NSCoder) {
        connector = .init(rawValue: c.decodeInteger(forKey: "connector")) ?? .j1772
        voltage = Measurement(value: c.decodeDouble(forKey: "volts"), unit: .volts); power = Measurement(value: c.decodeDouble(forKey: "kw"), unit: .kilowatts)
        super.init()
    }
}

// MARK: - panels (iOS 26)

@objc(CPPanelButtonConfiguration)
open class CPPanelButtonConfiguration: NSObject, NSSecureCoding {
    @objc open private(set) var primaryAction: CPTextButton
    @objc open private(set) var secondaryAction: CPTextButton?
    @objc public init(primaryAction: CPTextButton, secondaryAction: CPTextButton?) { self.primaryAction = primaryAction; self.secondaryAction = secondaryAction; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(primaryAction.title, forKey: "primary") }
    public required init?(coder c: NSCoder) {
        primaryAction = CPTextButton(title: (c.decodeObject(of: NSString.self, forKey: "primary") as String?) ?? "", textStyle: .normal, handler: nil)
        super.init()
    }
}

@objc(CPPanelItem)
open class CPPanelItem: NSObject, NSSecureCoding {
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var showsBottomSeparator: Bool = true
    @objc open var userInfo: Any?
    var _listItem: CPListItem?, _gridButtons: [CPGridButton] = []
    @objc public init(listItem: CPListItem) { _listItem = listItem; super.init() }
    @objc public init(gridButtons: [CPGridButton]) { _gridButtons = gridButtons; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(isEnabled, forKey: "enabled") }
    public required init?(coder c: NSCoder) { _isEnabled = c.containsValue(forKey: "enabled") ? c.decodeBool(forKey: "enabled") : true; super.init() }
}

@objc(CPPanel)
open class CPPanel: CPTemplate {
    @objc open var showsCloseButton: Bool = true { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open class var maximumPanelItemsCount: Int { 6 }
    public override init() { super.init() }
    public required init?(coder c: NSCoder) { showsCloseButton = c.decodeBool(forKey: "close"); super.init(coder: c) }
    open override func encode(with c: NSCoder) { super.encode(with: c); c.encode(showsCloseButton, forKey: "close") }
}

@objc(CPMapPanelItem)
open class CPMapPanelItem: NSObject {
    var _text: String, _detail: String?
    var _handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?
    init(_text: String, detail: String?, handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) { self._text = _text; _detail = detail; _handler = handler; super.init() }
    @objc public convenience init(trip: CPTrip, handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) {
        self.init(_text: trip._destinationName, detail: trip.routeChoices.first?.summaryVariants.first, handler: handler)
    }
    @objc public convenience init(routeChoice: CPRouteChoice, handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) {
        self.init(_text: routeChoice.summaryVariants.first ?? "Route", detail: routeChoice.travelEstimates?._text, handler: handler)
    }
    @objc public convenience init(travelEstimates: CPTravelEstimates, handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) {
        self.init(_text: travelEstimates._text, detail: nil, handler: handler)
    }
    @objc public convenience init(routeDetails: [CPRouteDetail], handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) {
        self.init(_text: routeDetails.map(\._value).joined(separator: " · "), detail: nil, handler: handler)
    }
    @objc public convenience init(mapTemplateWaypoint: CPMapTemplateWaypoint, image: UIImage?, handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) {
        self.init(_text: mapTemplateWaypoint.waypoint.name ?? "Stop", detail: mapTemplateWaypoint.travelEstimates._text, handler: handler)
    }
    @objc public convenience init(chargingStationConnection: CPChargingStationConnection, handler: ((CPMapPanelItem, @escaping () -> Void) -> Void)?) {
        self.init(_text: MeasurementFormatter().string(from: chargingStationConnection.power), detail: nil, handler: handler)
    }
}

@objc(CPMapPanelSection)
open class CPMapPanelSection: NSObject, NSSecureCoding {
    @objc open private(set) var title: String?
    @objc open private(set) var items: [CPMapPanelItem]
    @objc public init(title: String?, items: [CPMapPanelItem]) { self.title = title; self.items = items; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(title, forKey: "title") }
    public required init?(coder c: NSCoder) { title = c.decodeObject(of: NSString.self, forKey: "title") as String?; items = []; super.init() }
}

@objc(CPMapPanelButtonConfiguration)
open class CPMapPanelButtonConfiguration: CPPanelButtonConfiguration {
    @objc open private(set) var secondaryButton: CPButton?
    @objc open private(set) var travelEstimates: CPTravelEstimates?
    @objc public init(primaryAction: CPTextButton, secondaryButton: CPButton?, travelEstimates: CPTravelEstimates) {
        self.secondaryButton = secondaryButton; self.travelEstimates = travelEstimates
        super.init(primaryAction: primaryAction, secondaryAction: nil)
    }
    public required init?(coder c: NSCoder) { super.init(coder: c) }
}

@objc(CPMapPanelDelegate)
public protocol _CPMapPanelDelegate: NSObjectProtocol {
    @objc optional func panelDidShow(_ panel: CPMapPanel)
    @objc optional func panelDidHide(_ panel: CPMapPanel)
}

@objc(CPMapPanel)
open class CPMapPanel: CPPanel {
    public typealias Delegate = _CPMapPanelDelegate
    @objc open weak var delegate: (any CPMapPanel.Delegate)?
    @objc open var title: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var sections: [CPMapPanelSection] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var buttonConfiguration: CPMapPanelButtonConfiguration? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc public init(title: String?, sections: [CPMapPanelSection], buttonConfiguration: CPMapPanelButtonConfiguration?) {
        self.title = title; self.sections = sections; self.buttonConfiguration = buttonConfiguration
        super.init()
    }
    public required init?(coder c: NSCoder) { sections = []; super.init(coder: c) }
}

// MARK: - navigation alerts

@objc(CPNavigationAlert)
open class CPNavigationAlert: NSObject, NSSecureCoding {
    @objc(CPNavigationAlertDismissalContext) public enum DismissalContext: UInt, @unchecked Sendable { case timeout = 0, userDismissed, systemDismissed }
    @objc open private(set) var titleVariants: [String]
    @objc open private(set) var subtitleVariants: [String]
    @objc open private(set) var image: UIImage?
    @objc open private(set) var imageSet: CPImageSet?
    @objc open private(set) var primaryAction: CPAlertAction
    @objc open private(set) var secondaryAction: CPAlertAction?
    @objc open private(set) var duration: TimeInterval
    @objc open private(set) var actions: [CPAlertAction] = []
    @objc open private(set) var avatarImage: UIImage?
    @objc open private(set) var alertImage: UIImage?
    @objc open var showsCloseButton: Bool = false
    @objc open class var maximumActionsCount: Int { 2 }
    @objc open class var maximumAlertImageSize: CGSize { CGSize(width: 40, height: 40) }
    @objc open class var maximumAvatarImageSize: CGSize { CGSize(width: 40, height: 40) }
    @objc public init(titleVariants: [String], subtitleVariants: [String]?, imageSet: CPImageSet?, primaryAction: CPAlertAction, secondaryAction: CPAlertAction?, duration: TimeInterval) {
        self.titleVariants = titleVariants; self.subtitleVariants = subtitleVariants ?? []; self.imageSet = imageSet
        self.primaryAction = primaryAction; self.secondaryAction = secondaryAction; self.duration = duration
        actions = [primaryAction] + (secondaryAction.map { [$0] } ?? [])
        super.init()
    }
    @objc public convenience init(titleVariants: [String], subtitleVariants: [String]?, image: UIImage?, primaryAction: CPAlertAction, secondaryAction: CPAlertAction?, duration: TimeInterval) {
        self.init(titleVariants: titleVariants, subtitleVariants: subtitleVariants, imageSet: nil, primaryAction: primaryAction, secondaryAction: secondaryAction, duration: duration)
        self.image = image
    }
    @objc public init(titleVariants: [String], subtitleVariants: [String], avatarImage: UIImage?, alertImage: UIImage?, actions: [CPAlertAction], duration: TimeInterval) {
        self.titleVariants = titleVariants; self.subtitleVariants = subtitleVariants; self.avatarImage = avatarImage; self.alertImage = alertImage
        self.actions = Array(actions.prefix(Self.maximumActionsCount)); self.duration = duration
        primaryAction = actions.first ?? CPAlertAction(title: "OK", style: .default) { _ in }
        secondaryAction = actions.count > 1 ? actions[1] : nil
        super.init()
    }
    @nonobjc public convenience init(titleVariants: [String], subtitleVariants: [String], avatarImage: UIImage?, alert: UIImage?, actions: [CPAlertAction], duration: TimeInterval) {
        self.init(titleVariants: titleVariants, subtitleVariants: subtitleVariants, avatarImage: avatarImage, alertImage: alert, actions: actions, duration: duration)
    }
    @objc open func updateTitleVariants(_ newTitleVariants: [String], subtitleVariants newSubtitleVariants: [String]) {
        titleVariants = newTitleVariants; subtitleVariants = newSubtitleVariants; _CPCar.shared.setNeedsRender()
    }
    @objc(updateTitleVariants:subtitleVariants:avatarImage:alertImage:actions:duration:)
    open func updateTitleVariants(_ newTitleVariants: [String], subtitleVariants newSubtitleVariants: [String], avatarImage: UIImage?, alert alertImage: UIImage?,
                                  actions: [CPAlertAction], duration: TimeInterval) {
        titleVariants = newTitleVariants; subtitleVariants = newSubtitleVariants; self.avatarImage = avatarImage; self.alertImage = alertImage
        self.actions = Array(actions.prefix(Self.maximumActionsCount)); self.duration = duration
        _CPCar.shared.setNeedsRender()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(titleVariants, forKey: "titles"); c.encode(subtitleVariants, forKey: "subtitles"); c.encode(duration, forKey: "duration") }
    public required init?(coder c: NSCoder) {
        titleVariants = _cpDecodeStrings(c, "titles"); subtitleVariants = _cpDecodeStrings(c, "subtitles"); duration = c.decodeDouble(forKey: "duration")
        primaryAction = CPAlertAction(title: "OK", style: .default) { _ in }
        super.init()
    }
}

// MARK: - the navigation session

@objc(CPNavigationSession)
open class CPNavigationSession: NSObject {
    @objc(CPTripPauseReason) public enum PauseReason: UInt, @unchecked Sendable { case arrived = 1, loading, locating, rerouting, proceedToRoute }
    @objc open private(set) var trip: CPTrip
    @objc open var upcomingManeuvers: [CPManeuver] = [] { didSet { _CPCar.shared.setNeedsRender(); _log() } }
    @objc open var maneuverState: CPManeuverState = .continue { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var currentRoadNameVariants: [String] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var currentLaneGuidance: CPLaneGuidance? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open private(set) var routeSegments: [CPRouteSegment] = []
    @objc open private(set) var currentSegment: CPRouteSegment?
    var _isRouteSharingEnabled: Bool = false
    @objc open var isRouteSharingEnabled: Bool {
        @objc(isRouteSharingEnabled) get { _isRouteSharingEnabled }
        @objc(setRouteSharingEnabled:) set { _isRouteSharingEnabled = newValue }
    }
    var _isRouteSharingSupported: Bool = false
    @objc open var isRouteSharingSupported: Bool {
        @objc(isRouteSharingSupported) get { _isRouteSharingSupported }
        @objc(setRouteSharingSupported:) set { _isRouteSharingSupported = newValue }
    }
    @objc open var optionsPanel: CPMapPanel?
    weak var _map: CPMapTemplate?
    var _estimates: [ObjectIdentifier: CPTravelEstimates] = [:]
    var _maneuvers: [CPManeuver] = [], _lanes: [CPLaneGuidance] = []
    var _paused: (CPNavigationSession.PauseReason, String?)?
    var _ended = false
    init(trip: CPTrip, map: CPMapTemplate) { self.trip = trip; _map = map; super.init() }

    func _log() { if let m = upcomingManeuvers.first { NSLog("isim CarPlay: guidance %@", m._instruction) } }
    @objc open func updateEstimates(_ estimates: CPTravelEstimates, for maneuver: CPManeuver) {
        _estimates[ObjectIdentifier(maneuver)] = estimates; _CPCar.shared.setNeedsRender()
    }
    @objc(addManeuvers:) open func add(_ maneuvers: [CPManeuver]) { _maneuvers += maneuvers }
    @objc(addLaneGuidances:) open func add(_ laneGuidances: [CPLaneGuidance]) { _lanes += laneGuidances }
    @objc(addRouteSegments:) open func addRouteSegments(_ routeSegments: [CPRouteSegment]) { self.routeSegments += routeSegments }
    @objc(pauseTripForReason:description:) open func pauseTrip(for reason: CPNavigationSession.PauseReason, description: String?) {
        _paused = (reason, description); _CPCar.shared.setNeedsRender()
        NSLog("isim CarPlay: trip paused (%@)", description ?? "\(reason.rawValue)")
    }
    @objc(pauseTripForReason:description:turnCardColor:) open func pauseTrip(for reason: CPNavigationSession.PauseReason, description: String?, turnCardColor: UIColor?) {
        pauseTrip(for: reason, description: description)
    }
    @objc(resumeTripWithUpdatedRouteInformation:) open func resumeTrip(updatedRouteInformation routeInformation: CPRouteInformation) {
        _paused = nil; upcomingManeuvers = routeInformation.currentManeuvers; currentLaneGuidance = routeInformation.currentLaneGuidance
        if let m = routeInformation.currentManeuvers.first { _estimates[ObjectIdentifier(m)] = routeInformation.maneuverTravelEstimates }
        _map?._tripEstimates[ObjectIdentifier(trip)] = routeInformation.tripTravelEstimates
    }
    @objc(resumeTripWithUpdatedRouteSegments:currentSegment:rerouteReason:)
    open func resumeTrip(updatedRouteSegments routeSegments: [CPRouteSegment], currentSegment: CPRouteSegment, rerouteReason: CPRerouteReason) {
        self.routeSegments = routeSegments; self.currentSegment = currentSegment; _paused = nil
        upcomingManeuvers = currentSegment.currentManeuvers; currentLaneGuidance = currentSegment.currentLaneGuidance
    }
    @objc(resumeNavigationWithUpdatedTrip:routeSegments:currentSegment:rerouteReason:)
    open func resumeNavigation(updatedTrip trip: CPTrip, routeSegments: [CPRouteSegment], currentSegment: CPRouteSegment, rerouteReason: CPRerouteReason) {
        self.trip = trip
        resumeTrip(updatedRouteSegments: routeSegments, currentSegment: currentSegment, rerouteReason: rerouteReason)
    }
    @objc open func finishTrip() { _end("finished") }
    @objc open func cancelTrip() { _end("cancelled") }
    func _end(_ how: String) {
        guard !_ended else { return }
        _ended = true
        if _map?._session === self { _map?._session = nil }
        NSLog("isim CarPlay: trip %@", how)
        _CPCar.shared.setNeedsRender()
    }
}

// MARK: - the map template

@objc(CPMapTemplateDelegate)
public protocol CPMapTemplateDelegate: NSObjectProtocol {
    @objc optional func mapTemplateShouldProvideNavigationMetadata(_ mapTemplate: CPMapTemplate) -> Bool
    @objc(mapTemplate:shouldShowNotificationForManeuver:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, shouldShowNotificationFor maneuver: CPManeuver) -> Bool
    @objc(mapTemplate:shouldUpdateNotificationForManeuver:withTravelEstimates:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, shouldUpdateNotificationFor maneuver: CPManeuver, with travelEstimates: CPTravelEstimates) -> Bool
    @objc(mapTemplate:shouldShowNotificationForNavigationAlert:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, shouldShowNotificationFor navigationAlert: CPNavigationAlert) -> Bool
    @objc optional func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate)
    @objc optional func mapTemplateWillDismissPanningInterface(_ mapTemplate: CPMapTemplate)
    @objc optional func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate)
    @objc(mapTemplate:panBeganWithDirection:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, panBeganWith direction: CPMapTemplate.PanDirection)
    @objc(mapTemplate:panWithDirection:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection)
    @objc(mapTemplate:panEndedWithDirection:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, panEndedWith direction: CPMapTemplate.PanDirection)
    @objc optional func mapTemplateDidBeginPanGesture(_ mapTemplate: CPMapTemplate)
    @objc(mapTemplate:didUpdatePanGestureWithTranslation:velocity:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, didUpdatePanGestureWithTranslation translation: CGPoint, velocity: CGPoint)
    @objc(mapTemplate:didEndPanGestureWithVelocity:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didEndPanGestureWithVelocity velocity: CGPoint)
    @objc optional func mapTemplateDidBeginZoomGesture(_ mapTemplate: CPMapTemplate)
    @objc(mapTemplate:didUpdateZoomGestureWithCenter:scale:velocity:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, didUpdateZoomGestureWithCenter center: CGPoint, scale: CGFloat, velocity: CGFloat)
    @objc(mapTemplate:didEndZoomGestureWithVelocity:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didEndZoomGestureWithVelocity velocity: CGFloat)
    @objc optional func mapTemplateDidBeginPitchGesture(_ mapTemplate: CPMapTemplate)
    @objc(mapTemplate:pitchWithCenter:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, pitchWithCenter center: CGPoint)
    @objc(mapTemplate:pitchEndedWithCenter:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, pitchEndedWithCenter center: CGPoint)
    @objc optional func mapTemplateDidBeginRotationGesture(_ mapTemplate: CPMapTemplate)
    @objc(mapTemplate:didRotateWithCenter:rotation:velocity:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, didRotateWithCenter center: CGPoint, rotation: CGFloat, velocity: CGFloat)
    @objc(mapTemplate:rotationDidEndWithVelocity:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, rotationDidEndWithVelocity velocity: CGFloat)
    @objc(mapTemplate:willShowNavigationAlert:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, willShow navigationAlert: CPNavigationAlert)
    @objc(mapTemplate:didShowNavigationAlert:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didShow navigationAlert: CPNavigationAlert)
    @objc(mapTemplate:willDismissNavigationAlert:dismissalContext:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, willDismiss navigationAlert: CPNavigationAlert, dismissalContext: CPNavigationAlert.DismissalContext)
    @objc(mapTemplate:didDismissNavigationAlert:dismissalContext:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, didDismiss navigationAlert: CPNavigationAlert, dismissalContext: CPNavigationAlert.DismissalContext)
    @objc(mapTemplate:selectedPreviewForTrip:usingRouteChoice:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice)
    @objc(mapTemplate:startedTrip:usingRouteChoice:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice)
    @objc optional func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate)
    @objc(mapTemplate:displayStyleForManeuver:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, displayStyleFor maneuver: CPManeuver) -> CPManeuverDisplayStyle
    // route sharing (iOS 26)
    @objc optional func mapTemplateShouldProvideRouteSharing(_ mapTemplate: CPMapTemplate) -> Bool
    @objc(mapTemplate:didUpdateRouteSharingEnabled:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didUpdateRouteSharingEnabled enabled: Bool)
    @objc(mapTemplate:willShareDestinationForTrip:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, willShareDestinationFor trip: CPTrip)
    @objc(mapTemplate:didShareDestinationForTrip:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didShareDestinationFor trip: CPTrip)
    @objc(mapTemplate:didFailToShareDestinationForTrip:error:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didFailToShareDestinationFor trip: CPTrip, error: any Error)
    // multi-stop routes and the car's route source (iOS 26)
    @objc optional func mapTemplateShouldProvideMultiStopRouting(_ mapTemplate: CPMapTemplate) -> Bool
    @objc(mapTemplate:didReceiveUpdatedRouteSource:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didReceiveUpdatedRouteSource routeSource: CPRouteSource)
    @objc(mapTemplate:didReceiveRequestForDestination:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didReceiveRequestForDestination waypoint: CPNavigationWaypoint)
    @objc(mapTemplate:didRequestToInsertWaypoint:intoSegment:completion:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, didRequestToInsert waypoint: CPNavigationWaypoint, into segment: CPRouteSegment, completion: @escaping (CPTravelEstimates) -> Void)
    @objc(mapTemplate:didRequestToRemoveWaypoint:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didRequestToRemove waypoint: CPNavigationWaypoint)
    @objc(mapTemplate:didRequestToRemoveDestination:) optional func mapTemplate(_ mapTemplate: CPMapTemplate, didRequestToRemoveDestination waypoint: CPNavigationWaypoint)
    @objc(mapTemplate:waypoint:accepted:forSegment:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, waypoint: CPNavigationWaypoint, accepted: Bool, forSegment segment: CPRouteSegment?)
    @objc(mapTemplate:didRequestMultiStopCardConfigurationWithCompletion:)
    optional func mapTemplate(_ mapTemplate: CPMapTemplate, didRequestMultiStopCardConfigurationWithCompletion completion: @escaping (CPMultiStopCardConfiguration) -> Void)
}

/// a navigation app's map: the app draws its map in the CPWindow (carWindow); CarPlay draws the template's navigation
/// bar, map buttons, trip previews, guidance card, estimates, panels and navigation alerts over it
@objc(CPMapTemplate)
open class CPMapTemplate: CPTemplate, CPBarButtonProviding {
    @objc open weak var mapDelegate: (any CPMapTemplateDelegate)?
    @objc open var guidanceBackgroundColor: UIColor = UIColor(white: 0.12, alpha: 1) { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var tripEstimateStyle: CPTripEstimateStyle = .dark { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var mapButtons: [CPMapButton] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var automaticallyHidesNavigationBar: Bool = true
    @objc open var hidesButtonsWithNavigationBar: Bool = false
    @objc open var leadingNavigationBarButtons: [CPBarButton] { get { _leading } set { _leading = newValue } }
    @objc open var trailingNavigationBarButtons: [CPBarButton] { get { _trailing } set { _trailing = newValue } }
    @objc open var backButton: CPBarButton? { get { _back } set { _back = newValue } }
    @objc open private(set) var currentNavigationAlert: CPNavigationAlert?
    @objc open private(set) var isPanningInterfaceVisible: Bool = false

    var _previews: [CPTrip] = [], _selectedPreview = 0, _previewText: CPTripPreviewTextConfiguration?, _choicesOnly = false
    var _session: CPNavigationSession?
    var _tripEstimates: [ObjectIdentifier: CPTravelEstimates] = [:]
    var _tripColors: [ObjectIdentifier: CPTimeRemainingColor] = [:]
    var _panels: [CPMapPanel] = []
    var _alertTimer: Timer?

    public override init() { super.init() }
    public required init?(coder c: NSCoder) { super.init(coder: c) }

    @objc open func showTripPreviews(_ tripPreviews: [CPTrip], textConfiguration: CPTripPreviewTextConfiguration?) {
        showTripPreviews(tripPreviews, selectedTrip: nil, textConfiguration: textConfiguration)
    }
    @objc open func showTripPreviews(_ tripPreviews: [CPTrip], selectedTrip: CPTrip?, textConfiguration: CPTripPreviewTextConfiguration?) {
        _previews = Array(tripPreviews.prefix(12)); _previewText = textConfiguration; _choicesOnly = false
        _selectedPreview = selectedTrip.flatMap { s in _previews.firstIndex { $0 === s } } ?? 0
        NSLog("isim CarPlay: trip previews %@", _previews.map(\._destinationName).joined(separator: ", "))
        _CPCar.shared.setNeedsRender()
        _previewSelected()
    }
    @objc(showRouteChoicesPreviewForTrip:textConfiguration:) open func showRouteChoicesPreview(for tripPreview: CPTrip, textConfiguration: CPTripPreviewTextConfiguration?) {
        _previews = [tripPreview]; _selectedPreview = 0; _previewText = textConfiguration; _choicesOnly = true
        _CPCar.shared.setNeedsRender()
        _previewSelected()
    }
    @objc open func hideTripPreviews() { _previews = []; _CPCar.shared.setNeedsRender() }
    func _previewSelected() {
        guard _selectedPreview < _previews.count, let r = _previews[_selectedPreview].routeChoices.first else { return }
        mapDelegate?.mapTemplate?(self, selectedPreviewFor: _previews[_selectedPreview], using: r)
    }
    /// the trip preview's Go button: the delegate starts the trip (it calls startNavigationSession(for:))
    func _startPreview() {
        guard _selectedPreview < _previews.count else { return }
        let t = _previews[_selectedPreview]
        guard let r = t.routeChoices.first else { return }
        NSLog("isim CarPlay: start trip to %@", t._destinationName)
        mapDelegate?.mapTemplate?(self, startedTrip: t, using: r)
    }
    @objc(updateEstimates:forTrip:) open func updateEstimates(_ estimates: CPTravelEstimates, for trip: CPTrip) {
        _tripEstimates[ObjectIdentifier(trip)] = estimates; _CPCar.shared.setNeedsRender()
    }
    @objc(updateTravelEstimates:forTrip:withTimeRemainingColor:)
    open func update(_ estimates: CPTravelEstimates, for trip: CPTrip, with timeRemainingColor: CPTimeRemainingColor) {
        _tripColors[ObjectIdentifier(trip)] = timeRemainingColor
        updateEstimates(estimates, for: trip)
    }
    @objc(startNavigationSessionForTrip:) open func startNavigationSession(for trip: CPTrip) -> CPNavigationSession {
        _session?._end("replaced")
        let s = CPNavigationSession(trip: trip, map: self)
        _session = s; _previews = []
        NSLog("isim CarPlay: navigation session to %@", trip._destinationName)
        _CPCar.shared.setNeedsRender()
        return s
    }
    /// the guidance card's End button: CarPlay ends the trip and tells the delegate
    func _cancelNavigation() {
        _session?._end("cancelled")
        mapDelegate?.mapTemplateDidCancelNavigation?(self)
    }

    @objc(presentNavigationAlert:animated:) open func present(navigationAlert: CPNavigationAlert, animated: Bool) {
        if let shown = currentNavigationAlert { _dismissAlert(shown, .systemDismissed) }
        if mapDelegate?.mapTemplate?(self, shouldShowNotificationFor: navigationAlert) == false, !_CPCar.shared.foreground { return }
        mapDelegate?.mapTemplate?(self, willShow: navigationAlert)
        currentNavigationAlert = navigationAlert
        NSLog("isim CarPlay: navigation alert %@", navigationAlert.titleVariants.first ?? "")
        _CPCar.shared.setNeedsRender()
        mapDelegate?.mapTemplate?(self, didShow: navigationAlert)
        _alertTimer?.invalidate()
        if navigationAlert.duration > 0 {
            _alertTimer = Timer.scheduledTimer(withTimeInterval: max(navigationAlert.duration, _cpAlertMinimumDuration), repeats: false) { [weak self, weak navigationAlert] _ in
                if let self, let a = navigationAlert, self.currentNavigationAlert === a { self._dismissAlert(a, .timeout) }
            }
        }
    }
    @objc open func dismissNavigationAlert(animated: Bool, completion: @escaping (Bool) -> Void) {
        guard let a = currentNavigationAlert else { completion(false); return }
        _dismissAlert(a, .systemDismissed)
        completion(true)
    }
    func _dismissAlert(_ a: CPNavigationAlert, _ context: CPNavigationAlert.DismissalContext) {
        mapDelegate?.mapTemplate?(self, willDismiss: a, dismissalContext: context)
        currentNavigationAlert = nil; _alertTimer?.invalidate()
        _CPCar.shared.setNeedsRender()
        mapDelegate?.mapTemplate?(self, didDismiss: a, dismissalContext: context)
    }
    /// an alert's button: its handler runs, the alert goes away
    func _alertAction(_ i: Int) {
        guard let a = currentNavigationAlert, i < a.actions.count else { return }
        let act = a.actions[i]
        _dismissAlert(a, .userDismissed)
        act.handler(act)
    }

    @objc open func showPanningInterface(animated: Bool) {
        guard !isPanningInterfaceVisible else { return }
        isPanningInterfaceVisible = true; _CPCar.shared.setNeedsRender()
        mapDelegate?.mapTemplateDidShowPanningInterface?(self)
    }
    @objc open func dismissPanningInterface(animated: Bool) {
        guard isPanningInterfaceVisible else { return }
        mapDelegate?.mapTemplateWillDismissPanningInterface?(self)
        isPanningInterfaceVisible = false; _CPCar.shared.setNeedsRender()
        mapDelegate?.mapTemplateDidDismissPanningInterface?(self)
    }
    /// the panning interface's arrows (or `carplay pan up|down|left|right`)
    func _pan(_ d: CPMapTemplate.PanDirection) {
        mapDelegate?.mapTemplate?(self, panBeganWith: d)
        mapDelegate?.mapTemplate?(self, panWith: d)
        mapDelegate?.mapTemplate?(self, panEndedWith: d)
    }

    @objc open func showPanel(_ panel: CPMapPanel, completion: ((Bool, (any Error)?) -> Void)?) {
        for p in _panels { p.delegate?.panelDidHide?(p) }
        _panels = [panel]; _CPCar.shared.setNeedsRender(); panel.delegate?.panelDidShow?(panel); completion?(true, nil)
    }
    @objc open func pushPanel(_ panel: CPMapPanel, completion: ((Bool, (any Error)?) -> Void)?) {
        _panels.append(panel); _CPCar.shared.setNeedsRender(); panel.delegate?.panelDidShow?(panel); completion?(true, nil)
    }
    @objc open func popPanel(completion: ((Bool, (any Error)?) -> Void)?) {
        guard let p = _panels.popLast() else { completion?(false, _cpError("No panel to pop.")); return }
        _CPCar.shared.setNeedsRender(); p.delegate?.panelDidHide?(p); completion?(true, nil)
    }
    @objc open func hidePanel(completion: ((Bool, (any Error)?) -> Void)?) {
        guard !_panels.isEmpty else { completion?(false, _cpError("No panel is shown.")); return }
        let gone = _panels; _panels = []; _CPCar.shared.setNeedsRender()
        for p in gone { p.delegate?.panelDidHide?(p) }
        completion?(true, nil)
    }
}

/// NSStringFromCPManeuverType's text (the header's C function is CarPlay.framework's)
func _cpManeuverName(_ t: CPManeuverType) -> String { "CPManeuverType(\(t.rawValue))" }
