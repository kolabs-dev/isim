// isim MapKit: map geometry — the Web Mercator projection in MapKit's map points (the world is
// 268435456 x 268435456 points), regions, spans, map rects and conversions.
import Foundation
@_exported import CoreLocation
import UIKit

public typealias MKZoomScale = CGFloat

public struct MKCoordinateSpan: Hashable, Sendable, CustomStringConvertible {
    public var latitudeDelta: CLLocationDegrees
    public var longitudeDelta: CLLocationDegrees
    public init() { latitudeDelta = 0; longitudeDelta = 0 }
    public init(latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees) { self.latitudeDelta = latitudeDelta; self.longitudeDelta = longitudeDelta }
    public var description: String { String(format: "MKCoordinateSpan(%.6f, %.6f)", latitudeDelta, longitudeDelta) }
}

public struct MKCoordinateRegion: Sendable, CustomStringConvertible {
    public var center: CLLocationCoordinate2D
    public var span: MKCoordinateSpan
    public init() { center = CLLocationCoordinate2D(); span = MKCoordinateSpan() }
    public init(center: CLLocationCoordinate2D, span: MKCoordinateSpan) { self.center = center; self.span = span }
    public init(center: CLLocationCoordinate2D, latitudinalMeters: CLLocationDistance, longitudinalMeters: CLLocationDistance) {
        self.center = center
        let latDelta = latitudinalMeters / 111_132.954
        let lonDelta = longitudinalMeters / max(1e-9, 111_319.49 * cos(center.latitude * .pi / 180))
        span = MKCoordinateSpan(latitudeDelta: min(180, latDelta), longitudeDelta: min(360, lonDelta))
    }
    public init(_ rect: MKMapRect) { self = MKCoordinateRegionForMapRect(rect) }
    public var description: String {
        String(format: "MKCoordinateRegion(center: %.6f, %.6f, span: %.6f, %.6f)", center.latitude, center.longitude, span.latitudeDelta, span.longitudeDelta)
    }
}
public func MKCoordinateRegionMakeWithDistance(_ c: CLLocationCoordinate2D, _ lat: CLLocationDistance, _ lon: CLLocationDistance) -> MKCoordinateRegion {
    MKCoordinateRegion(center: c, latitudinalMeters: lat, longitudinalMeters: lon)
}
public func MKCoordinateRegionMake(_ c: CLLocationCoordinate2D, _ s: MKCoordinateSpan) -> MKCoordinateRegion { MKCoordinateRegion(center: c, span: s) }
public func MKCoordinateSpanMake(_ a: CLLocationDegrees, _ b: CLLocationDegrees) -> MKCoordinateSpan { MKCoordinateSpan(latitudeDelta: a, longitudeDelta: b) }

let _MKWorld: Double = 268_435_456

public struct MKMapPoint: Hashable, Sendable, CustomStringConvertible {
    public var x: Double
    public var y: Double
    public init() { x = 0; y = 0 }
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public init(_ c: CLLocationCoordinate2D) {
        let lat = max(-85.05112878, min(85.05112878, c.latitude)) * .pi / 180
        x = (c.longitude + 180) / 360 * _MKWorld
        y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * _MKWorld
    }
    public var coordinate: CLLocationCoordinate2D {
        let lon = x / _MKWorld * 360 - 180
        let n = Double.pi - 2 * .pi * y / _MKWorld
        let lat = 180 / .pi * atan(0.5 * (exp(n) - exp(-n)))
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    public func distance(to p: MKMapPoint) -> CLLocationDistance { MKMetersBetweenMapPoints(self, p) }
    public var description: String { String(format: "MKMapPoint(%.1f, %.1f)", x, y) }
}
public func MKMapPointForCoordinate(_ c: CLLocationCoordinate2D) -> MKMapPoint { MKMapPoint(c) }
public func MKCoordinateForMapPoint(_ p: MKMapPoint) -> CLLocationCoordinate2D { p.coordinate }
public func MKMapPointMake(_ x: Double, _ y: Double) -> MKMapPoint { MKMapPoint(x: x, y: y) }

public struct MKMapSize: Hashable, Sendable {
    public var width: Double
    public var height: Double
    public init() { width = 0; height = 0 }
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public static let world = MKMapSize(width: _MKWorld, height: _MKWorld)
}

public struct MKMapRect: Hashable, Sendable, CustomStringConvertible {
    public var origin: MKMapPoint
    public var size: MKMapSize
    public init() { origin = MKMapPoint(); size = MKMapSize() }
    public init(origin: MKMapPoint, size: MKMapSize) { self.origin = origin; self.size = size }
    public init(x: Double, y: Double, width: Double, height: Double) { origin = MKMapPoint(x: x, y: y); size = MKMapSize(width: width, height: height) }
    public static let world = MKMapRect(x: 0, y: 0, width: _MKWorld, height: _MKWorld)
    public static let null = MKMapRect(x: .infinity, y: .infinity, width: 0, height: 0)
    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }
    public var width: Double { size.width }
    public var height: Double { size.height }
    public var isNull: Bool { origin.x.isInfinite || origin.y.isInfinite }
    public var isEmpty: Bool { isNull || size.width == 0 || size.height == 0 }
    public var spans180thMeridian: Bool { maxX > _MKWorld }
    public func contains(_ p: MKMapPoint) -> Bool { p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY }
    public func contains(_ r: MKMapRect) -> Bool { r.minX >= minX && r.maxX <= maxX && r.minY >= minY && r.maxY <= maxY }
    public func intersects(_ r: MKMapRect) -> Bool { !(r.minX >= maxX || r.maxX <= minX || r.minY >= maxY || r.maxY <= minY) }
    public func union(_ r: MKMapRect) -> MKMapRect {
        if isNull { return r }; if r.isNull { return self }
        let x0 = min(minX, r.minX), y0 = min(minY, r.minY)
        return MKMapRect(x: x0, y: y0, width: max(maxX, r.maxX) - x0, height: max(maxY, r.maxY) - y0)
    }
    public func intersection(_ r: MKMapRect) -> MKMapRect {
        let x0 = max(minX, r.minX), y0 = max(minY, r.minY), x1 = min(maxX, r.maxX), y1 = min(maxY, r.maxY)
        return x1 > x0 && y1 > y0 ? MKMapRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0) : .null
    }
    public func insetBy(dx: Double, dy: Double) -> MKMapRect { MKMapRect(x: minX + dx, y: minY + dy, width: width - 2 * dx, height: height - 2 * dy) }
    public func offsetBy(dx: Double, dy: Double) -> MKMapRect { MKMapRect(x: minX + dx, y: minY + dy, width: width, height: height) }
    public var description: String { String(format: "MKMapRect(%.1f, %.1f, %.1f, %.1f)", minX, minY, width, height) }
}
public let MKMapRectWorld = MKMapRect.world
public let MKMapRectNull = MKMapRect.null
public func MKMapRectMake(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> MKMapRect { MKMapRect(x: x, y: y, width: w, height: h) }
public func MKMapRectContainsPoint(_ r: MKMapRect, _ p: MKMapPoint) -> Bool { r.contains(p) }
public func MKMapRectIntersectsRect(_ a: MKMapRect, _ b: MKMapRect) -> Bool { a.intersects(b) }
public func MKMapRectUnion(_ a: MKMapRect, _ b: MKMapRect) -> MKMapRect { a.union(b) }
public func MKMapRectIsNull(_ r: MKMapRect) -> Bool { r.isNull }

public func MKMapPointsPerMeterAtLatitude(_ latitude: CLLocationDegrees) -> Double {
    _MKWorld / (40_075_016.686 * cos(max(-85, min(85, latitude)) * .pi / 180))
}
public func MKMetersPerMapPointAtLatitude(_ latitude: CLLocationDegrees) -> CLLocationDistance { 1 / MKMapPointsPerMeterAtLatitude(latitude) }
public func MKMetersBetweenMapPoints(_ a: MKMapPoint, _ b: MKMapPoint) -> CLLocationDistance {
    _MKGeo.distance(a.coordinate, b.coordinate)
}
public func MKCoordinateRegionForMapRect(_ r: MKMapRect) -> MKCoordinateRegion {
    let nw = MKMapPoint(x: r.minX, y: r.minY).coordinate, se = MKMapPoint(x: r.maxX, y: r.maxY).coordinate
    let c = MKMapPoint(x: r.midX, y: r.midY).coordinate
    return MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: nw.latitude - se.latitude, longitudeDelta: r.width / _MKWorld * 360))
}
/// the map rect that covers a region
func _MKMapRect(for region: MKCoordinateRegion) -> MKMapRect {
    let c = region.center, s = region.span
    let a = MKMapPoint(CLLocationCoordinate2D(latitude: min(85.05, c.latitude + s.latitudeDelta / 2), longitude: c.longitude - s.longitudeDelta / 2))
    let b = MKMapPoint(CLLocationCoordinate2D(latitude: max(-85.05, c.latitude - s.latitudeDelta / 2), longitude: c.longitude + s.longitudeDelta / 2))
    return MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
}

enum _MKGeo {
    /// great-circle distance (haversine, mean Earth radius)
    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = 6_371_008.8, p1 = a.latitude * .pi / 180, p2 = b.latitude * .pi / 180
        let dp = p2 - p1, dl = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }
}

extension CLLocationCoordinate2D {
    func _equals(_ o: CLLocationCoordinate2D) -> Bool { latitude == o.latitude && longitude == o.longitude }
}

// MARK: - errors

public let MKErrorDomain = "MKErrorDomain"
public struct MKError: Error, CustomNSError, Hashable, LocalizedError, Sendable {
    public enum Code: UInt, Sendable { case unknown = 1, serverFailure, loadingThrottled, placemarkNotFound, directionsNotFound, decodingFailed }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { MKErrorDomain }
    public var errorCode: Int { Int(code.rawValue) }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? {
        switch code {
        case .directionsNotFound: return "Directions Not Available"
        case .placemarkNotFound: return "Placemark Not Found"
        case .serverFailure: return "The operation couldn’t be completed."
        default: return "The operation couldn’t be completed. (MKErrorDomain error \(code.rawValue).)"
        }
    }
    public static var unknown: Code { .unknown }
    public static var serverFailure: Code { .serverFailure }
    public static var loadingThrottled: Code { .loadingThrottled }
    public static var placemarkNotFound: Code { .placemarkNotFound }
    public static var directionsNotFound: Code { .directionsNotFound }
}
