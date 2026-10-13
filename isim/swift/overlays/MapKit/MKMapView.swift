// isim MapKit: MKMapView.
//
// Adapted: the map is drawn from isim's offline basemap (Basemap.swift); the camera is always north-up and flat
// (heading and pitch are stored, not rendered); panning is one-finger drag, zooming is double-tap (zoom in) and
// programmatic (no pinch gesture on isim); region changes are applied without animation. Annotation views,
// callouts, overlays and the user location follow MapKit's API and look like iOS 17.
import UIKit

public enum MKMapType: UInt, Sendable { case standard = 0, satellite, hybrid, satelliteFlyover, hybridFlyover, mutedStandard }
public enum MKUserTrackingMode: Int, Sendable { case none = 0, follow, followWithHeading }
public enum MKOverlayLevel: Int, Sendable { case aboveRoads = 0, aboveLabels }
public let MKMapViewDefaultAnnotationViewReuseIdentifier = "MKMapViewDefaultAnnotationViewReuseIdentifier"
public let MKMapViewDefaultClusterAnnotationViewReuseIdentifier = "MKMapViewDefaultClusterAnnotationViewReuseIdentifier"

open class MKMapCamera: NSObject, NSCopying, @unchecked Sendable {
    open var centerCoordinate = CLLocationCoordinate2D()
    open var centerCoordinateDistance: CLLocationDistance = 1000
    open var heading: CLLocationDirection = 0
    open var pitch: CGFloat = 0
    /// the eye's height above the ground (the distance to the centre, foreshortened by the pitch)
    open var altitude: CLLocationDistance {
        get { centerCoordinateDistance * cos(Double(pitch) * Double.pi / 180) }
        set { centerCoordinateDistance = newValue / max(0.05, cos(Double(pitch) * Double.pi / 180)) }
    }
    public override init() { super.init() }
    public convenience init(lookingAtCenter centerCoordinate: CLLocationCoordinate2D, fromDistance distance: CLLocationDistance, pitch: CGFloat, heading: CLLocationDirection) {
        self.init(); self.centerCoordinate = centerCoordinate; centerCoordinateDistance = distance; self.pitch = pitch; self.heading = heading
    }
    public convenience init(lookingAtCenter centerCoordinate: CLLocationCoordinate2D, fromEyeCoordinate eye: CLLocationCoordinate2D, eyeAltitude: CLLocationDistance) {
        // the eye looks down at the centre: the pitch from the ground distance and altitude, the heading from eye to centre
        self.init(); self.centerCoordinate = centerCoordinate
        let ground = _MKGeo.distance(eye, centerCoordinate)
        centerCoordinateDistance = (ground * ground + eyeAltitude * eyeAltitude).squareRoot()
        pitch = CGFloat(atan2(ground, max(0, eyeAltitude)) * 180 / Double.pi)
        if ground > 0.01 {
            let r = Double.pi / 180, la1 = eye.latitude * r, la2 = centerCoordinate.latitude * r, dl = (centerCoordinate.longitude - eye.longitude) * r
            let b = atan2(sin(dl) * cos(la2), cos(la1) * sin(la2) - sin(la1) * cos(la2) * cos(dl)) / r
            heading = (b + 360).truncatingRemainder(dividingBy: 360)
        }
    }
    public convenience init(lookingAt mapItem: MKMapItem, forViewSize viewSize: CGSize, allowPitch: Bool) {
        self.init(); centerCoordinate = mapItem.placemark.coordinate; centerCoordinateDistance = 1000
    }
    public func copy(with zone: OpaquePointer? = nil) -> Any {
        MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: centerCoordinateDistance, pitch: pitch, heading: heading)
    }
}

open class MKMapConfiguration: NSObject, @unchecked Sendable {
    public enum ElevationStyle: Int, Sendable { case flat = 0, realistic }
    open var elevationStyle: ElevationStyle = .flat
    var _type: MKMapType { .standard }
}
open class MKStandardMapConfiguration: MKMapConfiguration, @unchecked Sendable {
    public enum EmphasisStyle: Int, Sendable { case `default` = 0, muted }
    open var emphasisStyle: EmphasisStyle = .default
    open var pointOfInterestFilter: MKPointOfInterestFilter?
    open var showsTraffic = false
    public override init() { super.init() }
    public init(elevationStyle: ElevationStyle) { super.init(); self.elevationStyle = elevationStyle }
    public init(elevationStyle: ElevationStyle, emphasisStyle: EmphasisStyle) { super.init(); self.elevationStyle = elevationStyle; self.emphasisStyle = emphasisStyle }
    public init(emphasisStyle: EmphasisStyle) { super.init(); self.emphasisStyle = emphasisStyle }
    override var _type: MKMapType { emphasisStyle == .muted ? .mutedStandard : .standard }
}
open class MKImageryMapConfiguration: MKMapConfiguration, @unchecked Sendable {
    public override init() { super.init() }
    public init(elevationStyle: ElevationStyle) { super.init(); self.elevationStyle = elevationStyle }
    override var _type: MKMapType { .satellite }
}
open class MKHybridMapConfiguration: MKMapConfiguration, @unchecked Sendable {
    open var pointOfInterestFilter: MKPointOfInterestFilter?
    open var showsTraffic = false
    public override init() { super.init() }
    public init(elevationStyle: ElevationStyle) { super.init(); self.elevationStyle = elevationStyle }
    override var _type: MKMapType { .hybrid }
}

open class MKMapCameraZoomRange: NSObject, @unchecked Sendable {
    public let minCenterCoordinateDistance: CLLocationDistance
    public let maxCenterCoordinateDistance: CLLocationDistance
    public static let zoomDefault: CLLocationDistance = -1
    public init?(minCenterCoordinateDistance: CLLocationDistance, maxCenterCoordinateDistance: CLLocationDistance) {
        self.minCenterCoordinateDistance = minCenterCoordinateDistance; self.maxCenterCoordinateDistance = maxCenterCoordinateDistance; super.init()
    }
    public convenience init?(minCenterCoordinateDistance: CLLocationDistance) { self.init(minCenterCoordinateDistance: minCenterCoordinateDistance, maxCenterCoordinateDistance: .greatestFiniteMagnitude) }
    public convenience init?(maxCenterCoordinateDistance: CLLocationDistance) { self.init(minCenterCoordinateDistance: 0, maxCenterCoordinateDistance: maxCenterCoordinateDistance) }
}
open class MKMapCameraBoundary: NSObject, @unchecked Sendable {
    public let mapRect: MKMapRect
    public init?(mapRect: MKMapRect) { self.mapRect = mapRect; super.init() }
    public convenience init?(coordinateRegion region: MKCoordinateRegion) { self.init(mapRect: _MKMapRect(for: region)) }
}

/// MKMapViewDelegate (isim: a Swift protocol with default implementations — MapKit's types use Core Location's
/// Swift coordinate struct, which Objective-C protocols cannot carry).
@MainActor public protocol MKMapViewDelegate: AnyObject {
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool)
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView)
    func mapViewWillStartLoadingMap(_ mapView: MKMapView)
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView)
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool)
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView])
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl)
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView)
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation)
    func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation)
    func mapViewWillStartLocatingUser(_ mapView: MKMapView)
    func mapViewDidStopLocatingUser(_ mapView: MKMapView)
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation)
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error)
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool)
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer
    func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer])
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState)
}
extension MKMapViewDelegate {
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {}
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {}
    public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {}
    public func mapViewWillStartLoadingMap(_ mapView: MKMapView) {}
    public func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {}
    public func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {}
    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? { nil }
    public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {}
    public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {}
    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {}
    public func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {}
    public func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {}
    public func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {}
    public func mapViewWillStartLocatingUser(_ mapView: MKMapView) {}
    public func mapViewDidStopLocatingUser(_ mapView: MKMapView) {}
    public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {}
    public func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {}
    public func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {}
    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer { MKOverlayRenderer(overlay: overlay) }
    public func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) {}
    public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {}
}

/// the basemap layer: the map plane, drawn unrotated around `MKMapView._baseAnchor` (the view's centre) and turned
/// to the heading in its context; MKMapView tilts it in perspective for pitch
final class _MKBaseView: UIView {
    weak var map: MKMapView?
    override func draw(_ rect: CGRect) {
        guard let m = map, let ctx = UIGraphicsGetCurrentContext() else { return }
        let dark = traitCollection.userInterfaceStyle == .dark
        let a = m._baseAnchor, h = m._heading * Double.pi / 180, s = m._scale, c = m._center
        // this view's area in map-aligned view points from the centre (the bounding box of the rotated bounds)
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: bounds.width, y: 0), CGPoint(x: 0, y: bounds.height), CGPoint(x: bounds.width, y: bounds.height)]
            .map { MKMapView._rotate(Double($0.x - a.x), Double($0.y - a.y), h) }
        let area = CGRect(x: corners.map(\.0).min()!, y: corners.map(\.1).min()!, width: 0, height: 0)
            .union(CGRect(x: corners.map(\.0).max()!, y: corners.map(\.1).max()!, width: 0, height: 0))
        let visible = MKMapRect(x: c.x + Double(area.minX) * s, y: c.y + Double(area.minY) * s, width: Double(area.width) * s, height: Double(area.height) * s)
        let flat: (MKMapPoint) -> CGPoint = { p in
            var dx = p.x - c.x
            if dx < -_MKWorld / 2 { dx += _MKWorld } else if dx > _MKWorld / 2 { dx -= _MKWorld }   /* the copy nearest the centre */
            return CGPoint(x: dx / s, y: (p.y - c.y) / s)
        }
        ctx.saveGState()
        ctx.translateBy(x: a.x, y: a.y)
        ctx.rotate(by: CGFloat(-h))
        _MKBasemap.draw(visible: visible, scale: s, rect: area, type: m._effectiveType, dark: dark, showsLabels: false,
                        gridLabels: m._heading == 0 && m._pitch == 0, toView: flat)
        // overlays (above the basemap, below annotations)
        for (o, r) in m._overlayRenderers() where o.intersects(visible.insetBy(dx: -visible.width, dy: -visible.height)) {
            r._draw(toView: flat, scale: CGFloat(s), visible: visible)
        }
        if m.showsUserLocation, let loc = m.userLocation.location, loc.horizontalAccuracy > 0 {
            let p = flat(MKMapPoint(loc.coordinate))
            let r = CGFloat(loc.horizontalAccuracy * MKMapPointsPerMeterAtLatitude(loc.coordinate.latitude) / s)
            if r > 14 {
                UIColor.systemBlue.withAlphaComponent(0.12).setFill()
                UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
            }
        }
        ctx.restoreGState()
        // place names stay upright
        if m.pointOfInterestFilter.map({ $0.includes(.landmark) }) ?? true, !_MKBasemap.usesTiles {
            _MKBasemap.drawPlaces(visible: visible, scale: s, rect: bounds, st: _MKBasemap.style(m._effectiveType, dark: dark)) { p in
                let q = flat(p), r = MKMapView._rotate(Double(q.x), Double(q.y), -h)
                return CGPoint(x: a.x + CGFloat(r.0), y: a.y + CGFloat(r.1))
            }
        }
    }
}

/// the "isim map" note in the bottom-left corner (isim has no map data provider)
final class _MKAttributionView: UIView {
    weak var map: MKMapView?
    override func draw(_ rect: CGRect) {
        guard let m = map else { return }
        let note = _MKBasemap.usesTiles ? "isim map · tiles from local cache" : "isim map · offline basemap"
        _MKBasemap._text(note, at: CGPoint(x: 1, y: 1), font: .systemFont(ofSize: 10, weight: .medium), color: UIColor.secondaryLabel,
                         halo: m._effectiveType == .standard || m._effectiveType == .mutedStandard ? UIColor.systemBackground : nil)
    }
}

@MainActor
open class MKMapView: UIView, CLLocationManagerDelegate {
    open weak var delegate: MKMapViewDelegate?
    open var mapType: MKMapType = .standard { didSet { _base.setNeedsDisplay() } }
    open var preferredConfiguration: MKMapConfiguration = MKStandardMapConfiguration() { didSet { _base.setNeedsDisplay() } }
    open var isZoomEnabled = true
    open var isScrollEnabled = true
    open var isRotateEnabled = true
    open var isPitchEnabled = true
    open var showsCompass = true { didSet { setNeedsLayout() } }
    open var showsScale = false { didSet { setNeedsLayout() } }
    open var showsBuildings = true
    open var showsTraffic = false
    open var showsPointsOfInterest = true
    open var pointOfInterestFilter: MKPointOfInterestFilter?
    open var showsUserTrackingButton = false
    open var cameraZoomRange: MKMapCameraZoomRange! = MKMapCameraZoomRange(minCenterCoordinateDistance: 0)
    open var cameraBoundary: MKMapCameraBoundary?
    open var selectableMapFeatures: Int = 0
    open private(set) var userLocation = MKUserLocation()
    open var isUserLocationVisible: Bool { showsUserLocation && userLocation.location.map { visibleMapRect.contains(MKMapPoint($0.coordinate)) } ?? false }
    open var userTrackingMode: MKUserTrackingMode = .none {
        didSet { if oldValue != userTrackingMode { delegate?.mapView(self, didChange: userTrackingMode, animated: false); _follow() } }
    }
    open func setUserTrackingMode(_ mode: MKUserTrackingMode, animated: Bool) { userTrackingMode = mode }
    open var showsUserLocation = false { didSet { if oldValue != showsUserLocation { _locating(showsUserLocation) } } }

    // camera state: center (map points) and scale (map points per view point)
    var _center = MKMapPoint(CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902))
    var _scale: Double = 400
    var _initialRegionSet = false
    let _base = _MKBaseView()
    let _annotationLayer = UIView()
    var _annotations: [MKAnnotation] = []
    var _views: [ObjectIdentifier: MKAnnotationView] = [:]
    var _overlays: [MKOverlay] = []
    var _renderers: [ObjectIdentifier: MKOverlayRenderer] = [:]
    var _reuse: [String: [MKAnnotationView]] = [:]
    var _registered: [String: MKAnnotationView.Type] = [:]
    var _selected: MKAnnotation?
    var _callout: _MKCalloutView?
    var _location: CLLocationManager?
    lazy var _compass: MKCompassButton = MKCompassButton(mapView: self)
    lazy var _scaleView: MKScaleView = MKScaleView(mapView: self)
    let _attribution = _MKAttributionView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        _setup()
    }
    public required init?(coder: NSCoder) { super.init(coder: coder); _setup() }
    func _setup() {
        clipsToBounds = true
        backgroundColor = .clear
        _base.map = self
        _base.isUserInteractionEnabled = false
        _annotationLayer.backgroundColor = .clear
        _attribution.map = self
        _attribution.isUserInteractionEnabled = false
        _attribution.backgroundColor = .clear
        addSubview(_base)
        addSubview(_annotationLayer)
        addSubview(_attribution)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(_pan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        // two fingers: pinch to zoom, rotate, drag up or down to tilt (all at once, as on iOS)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(_pinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(_rotate(_:)))
        let tilt = UIPanGestureRecognizer(target: self, action: #selector(_tilt(_:)))
        tilt.minimumNumberOfTouches = 2
        for g in [pinch, rotate, tilt] as [UIGestureRecognizer] { g.delegate = _MKGestureFriend.shared; addGestureRecognizer(g) }
        let dbl = UITapGestureRecognizer(target: self, action: #selector(_doubleTap(_:)))
        dbl.numberOfTapsRequired = 2
        addGestureRecognizer(dbl)
        let tap = UITapGestureRecognizer(target: self, action: #selector(_tap(_:)))
        addGestureRecognizer(tap)
    }

    // MARK: geometry
    var _effectiveType: MKMapType { mapType != .standard ? mapType : preferredConfiguration._type }
    open var visibleMapRect: MKMapRect {
        get {
            let sz = _sizeForFit()
            let w = Double(sz.width) * _scale, h = Double(sz.height) * _scale
            if _heading == 0 && _pitch == 0 { return MKMapRect(x: _center.x - w / 2, y: _center.y - h / 2, width: w, height: h) }
            // rotated or tilted: the bounding rect of what the view shows
            let ps = [CGPoint(x: 0, y: 0), CGPoint(x: sz.width, y: 0), CGPoint(x: 0, y: sz.height), CGPoint(x: sz.width, y: sz.height)].map { _toMap($0) }
            let x0 = ps.map(\.x).min()!, y0 = ps.map(\.y).min()!
            return MKMapRect(x: x0, y: y0, width: ps.map(\.x).max()! - x0, height: ps.map(\.y).max()! - y0)
        }
        set { setVisibleMapRect(newValue, animated: false) }
    }
    open func setVisibleMapRect(_ mapRect: MKMapRect, animated: Bool) { setVisibleMapRect(mapRect, edgePadding: .zero, animated: animated) }
    open func setVisibleMapRect(_ mapRect: MKMapRect, edgePadding insets: UIEdgeInsets, animated: Bool) {
        guard !mapRect.isNull else { return }
        if bounds.width < 1 || bounds.height < 1 { _pendingFit = { [weak self] in self?.setVisibleMapRect(mapRect, edgePadding: insets, animated: animated) } } else { _pendingFit = nil }
        let size = _sizeForFit()
        let w = max(1, Double(size.width - insets.left - insets.right)), h = max(1, Double(size.height - insets.top - insets.bottom))
        let s = max(mapRect.width / w, mapRect.height / h)
        // keep the rect centered within the padded area
        let cx = mapRect.midX - Double(insets.left - insets.right) / 2 * s, cy = mapRect.midY - Double(insets.top - insets.bottom) / 2 * s
        _apply(center: MKMapPoint(x: cx, y: cy), scale: s, animated: animated)
    }
    open func mapRectThatFits(_ mapRect: MKMapRect) -> MKMapRect { mapRectThatFits(mapRect, edgePadding: .zero) }
    open func mapRectThatFits(_ mapRect: MKMapRect, edgePadding insets: UIEdgeInsets) -> MKMapRect {
        let size = _sizeForFit()
        let s = max(mapRect.width / Double(size.width), mapRect.height / Double(size.height))
        let w = Double(size.width) * s, h = Double(size.height) * s
        return MKMapRect(x: mapRect.midX - w / 2, y: mapRect.midY - h / 2, width: w, height: h)
    }
    func _sizeForFit() -> CGSize { bounds.width >= 1 && bounds.height >= 1 ? bounds.size : UIScreen.main.bounds.size }
    open var region: MKCoordinateRegion {
        get { MKCoordinateRegionForMapRect(visibleMapRect) }
        set { setRegion(newValue, animated: false) }
    }
    open func setRegion(_ region: MKCoordinateRegion, animated: Bool) {
        if bounds.width < 1 || bounds.height < 1 { _pendingFit = { [weak self] in self?.setRegion(region, animated: animated) } } else { _pendingFit = nil }
        let r = _MKMapRect(for: region)
        let size = _sizeForFit()
        let s = max(r.width / Double(size.width), r.height / Double(size.height))
        _apply(center: MKMapPoint(region.center), scale: s, animated: animated)
    }
    open func regionThatFits(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        MKCoordinateRegionForMapRect(mapRectThatFits(_MKMapRect(for: region)))
    }
    open var centerCoordinate: CLLocationCoordinate2D {
        get { _center.coordinate }
        set { setCenter(newValue, animated: false) }
    }
    open func setCenter(_ coordinate: CLLocationCoordinate2D, animated: Bool) { _apply(center: MKMapPoint(coordinate), scale: _scale, animated: animated) }
    /// MKMapCamera: the distance is the eye height that shows the map's visible height (30° vertical field of view)
    open var camera: MKMapCamera {
        get {
            let c = MKMapCamera()
            c.centerCoordinate = centerCoordinate
            let metersTall = Double(_sizeForFit().height) * _scale / MKMapPointsPerMeterAtLatitude(centerCoordinate.latitude)
            c.centerCoordinateDistance = metersTall / (2 * tan(15 * Double.pi / 180))
            c.heading = _heading; c.pitch = _pitch
            return c
        }
        set { setCamera(newValue, animated: false) }
    }
    /// heading: degrees clockwise from north at the top of the view; pitch: degrees from looking straight down
    var _heading: CLLocationDirection = 0, _pitch: CGFloat = 0
    /// the steepest tilt drawn (adapted: iOS allows more when zoomed in to a street, less when zoomed out)
    static let _maxPitch: CGFloat = 60
    open func setCamera(_ camera: MKMapCamera, animated: Bool) {
        if bounds.width < 1 || bounds.height < 1 { _pendingFit = { [weak self] in self?.setCamera(camera, animated: animated) } } else { _pendingFit = nil }
        let metersTall = camera.centerCoordinateDistance * 2 * tan(15 * Double.pi / 180)
        let s = metersTall * MKMapPointsPerMeterAtLatitude(camera.centerCoordinate.latitude) / Double(_sizeForFit().height)
        _apply(center: MKMapPoint(camera.centerCoordinate), scale: s, heading: camera.heading, pitch: camera.pitch, animated: animated)
    }
    open func setCameraZoomRange(_ range: MKMapCameraZoomRange?, animated: Bool) { cameraZoomRange = range }
    open func setCameraBoundary(_ boundary: MKMapCameraBoundary?, animated: Bool) { cameraBoundary = boundary }

    /// a camera change made before the view has a size: redone once it has one (the fit depends on the size)
    var _pendingFit: (() -> Void)?
    var _gesturing = false, _gestureMoved = false
    func _apply(center: MKMapPoint, scale: Double, heading: CLLocationDirection? = nil, pitch: CGFloat? = nil, animated: Bool) {
        var s = scale, c = center
        let maxScale = _MKWorld / Double(max(64, _sizeForFit().width)) * 1.2
        s = max(0.05, min(maxScale, s.isFinite && s > 0 ? s : _scale))
        // zoom range: centerCoordinateDistance limits
        if let zr = cameraZoomRange {
            let k = Double(_sizeForFit().height) / MKMapPointsPerMeterAtLatitude(c.coordinate.latitude) / (2 * tan(15 * Double.pi / 180))
            if zr.minCenterCoordinateDistance > 0 { s = max(s, zr.minCenterCoordinateDistance / k) }
            if zr.maxCenterCoordinateDistance < .greatestFiniteMagnitude { s = min(s, zr.maxCenterCoordinateDistance / k) }
        }
        if let b = cameraBoundary?.mapRect, !b.isNull { c = MKMapPoint(x: min(max(c.x, b.minX), b.maxX), y: min(max(c.y, b.minY), b.maxY)) }
        c.y = min(max(c.y, 0), _MKWorld)
        c.x = (c.x.truncatingRemainder(dividingBy: _MKWorld) + _MKWorld).truncatingRemainder(dividingBy: _MKWorld)
        var h = heading.map { $0.isFinite ? $0 : 0 } ?? _heading
        h = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let t = min(max(pitch.map { $0.isFinite ? $0 : 0 } ?? _pitch, 0), Self._maxPitch)
        _initialRegionSet = true
        _animation?.stop(); _animation = nil
        let changed = abs(c.x - _center.x) > 1e-6 || abs(c.y - _center.y) > 1e-6 || abs(s - _scale) > 1e-9 || abs(h - _heading) > 1e-9 || abs(t - _pitch) > 1e-9
        guard changed else { return }
        if !_gesturing || !_gestureMoved { delegate?.mapView(self, regionWillChangeAnimated: animated) }
        if _gesturing { _gestureMoved = true }
        if animated && window != nil && !_gesturing {
            // adapted: a 0.35 s ease-in-out from the current camera (zoom changes at a constant rate, the heading turns
            // the short way); the visible region is reported on each frame, regionDidChange at the end
            _animation = _MKCameraAnimation(map: self, from: (_center, _scale, _heading, _pitch), to: (c, s, h, t))
            return
        }
        _set(center: c, scale: s, heading: h, pitch: t)
        if !_gesturing { delegate?.mapView(self, regionDidChangeAnimated: animated) }   /* a drag reports it once, at the end */
    }
    var _animation: _MKCameraAnimation?
    /// moves the camera now (no checks, no will/did-change calls)
    func _set(center: MKMapPoint, scale: Double, heading: CLLocationDirection, pitch: CGFloat) {
        let tilted = (pitch != 0) != (_pitch != 0) || abs(pitch - _pitch) > 1e-9
        _center = center; _scale = scale; _heading = heading; _pitch = pitch
        if tilted { _layoutBase() }
        _regionChanged()
        delegate?.mapViewDidChangeVisibleRegion(self)
    }
    func _regionChanged() {
        _base.setNeedsDisplay()
        _compass.setNeedsDisplay(); _scaleView.setNeedsDisplay()
        setNeedsLayout()
        _layoutAnnotations()
    }
    // MARK: projection
    // The map is a plane: map point p lies at R(-heading)·(p - center) / scale view points from the view's centre
    // (east turns up for heading 90°). Pitch tilts the plane back about the view's horizontal centre line, seen in
    // perspective by the camera (30° vertical field of view, eye distance d): a plane point (x, y) is drawn at
    // centre + (x, y·cos θ) / (1 − y·sin θ / d). _MKBaseView draws the plane; its layer carries the same tilt.
    nonisolated static func _rotate(_ x: Double, _ y: Double, _ a: Double) -> (Double, Double) {
        let c = cos(a), s = sin(a)
        return (x * c - y * s, x * s + y * c)
    }
    var _eye: Double { Double(_sizeForFit().height) / 2 / tan(15 * Double.pi / 180) }
    /// where the base view's (unrotated) plane origin, the view's centre, is in the base view's own coordinates
    var _baseAnchor = CGPoint.zero
    var _toView: (MKMapPoint) -> CGPoint {
        let c = _center, s = _scale, h = _heading * Double.pi / 180, t = Double(_pitch) * Double.pi / 180, d = _eye
        let sz = _sizeForFit(), mx = Double(sz.width) / 2, my = Double(sz.height) / 2
        return { p in
            var dx = p.x - c.x
            // wrap around the 180th meridian to the copy nearest the view
            if dx < -_MKWorld / 2 { dx += _MKWorld } else if dx > _MKWorld / 2 { dx -= _MKWorld }
            var (x, y) = h == 0 ? (dx / s, (p.y - c.y) / s) : Self._rotate(dx / s, (p.y - c.y) / s, -h)
            if t != 0 {
                let w = max(1e-3, 1 - y * sin(t) / d)
                x /= w; y = y * cos(t) / w
            }
            return CGPoint(x: mx + x, y: my + y)
        }
    }
    /// the map point under a view point (on a tilted map, a point above the horizon gives the farthest point drawn)
    func _toMap(_ v: CGPoint) -> MKMapPoint {
        let sz = _sizeForFit(), h = _heading * Double.pi / 180, t = Double(_pitch) * Double.pi / 180, d = _eye
        var x = Double(v.x - sz.width / 2), y = Double(v.y - sz.height / 2)
        if t != 0 {
            let horizon = -d / tan(t) * 0.98
            y = max(y, horizon)
            let py = y / (cos(t) + y * sin(t) / d)
            x *= 1 - py * sin(t) / d; y = py
        }
        let (dx, dy) = h == 0 ? (x, y) : Self._rotate(x, y, h)
        return MKMapPoint(x: _center.x + dx * _scale, y: _center.y + dy * _scale)
    }
    open func convert(_ coordinate: CLLocationCoordinate2D, toPointTo view: UIView?) -> CGPoint {
        let p = _toView(MKMapPoint(coordinate))
        return view.map { convert(p, to: $0) } ?? p
    }
    open func convert(_ point: CGPoint, toCoordinateFrom view: UIView?) -> CLLocationCoordinate2D {
        let p = view.map { convert(point, from: $0) } ?? point
        return _toMap(p).coordinate
    }
    open func convert(_ region: MKCoordinateRegion, toRectTo view: UIView?) -> CGRect {
        let r = _MKMapRect(for: region), f = _toView
        let ps = [MKMapPoint(x: r.minX, y: r.minY), MKMapPoint(x: r.maxX, y: r.minY), MKMapPoint(x: r.minX, y: r.maxY), MKMapPoint(x: r.maxX, y: r.maxY)].map(f)
        let x0 = ps.map(\.x).min()!, y0 = ps.map(\.y).min()!
        let rect = CGRect(x: x0, y: y0, width: ps.map(\.x).max()! - x0, height: ps.map(\.y).max()! - y0)
        return view.map { convert(rect, to: $0) } ?? rect
    }
    open func convert(_ rect: CGRect, toRegionFrom view: UIView?) -> MKCoordinateRegion {
        let r = view.map { convert(rect, from: $0) } ?? rect
        let ps = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)].map { _toMap($0) }
        let x0 = ps.map(\.x).min()!, y0 = ps.map(\.y).min()!
        return MKCoordinateRegionForMapRect(MKMapRect(x: x0, y: y0, width: ps.map(\.x).max()! - x0, height: ps.map(\.y).max()! - y0))
    }

    // MARK: layout
    open override func layoutSubviews() {
        super.layoutSubviews()
        if _annotationLayer.frame != bounds { _annotationLayer.frame = bounds; _layoutBase() }
        if bounds.width >= 1, bounds.height >= 1, let f = _pendingFit { _pendingFit = nil; f() }
        _attribution.frame = CGRect(x: 9, y: bounds.maxY - 19, width: 200, height: 16)
        // the compass shows while the map is turned (adapted from iOS 17: top right, below the safe area)
        let showCompass = showsCompass && (abs(_heading) > 0.5 && abs(_heading - 360) > 0.5)
        if showCompass {
            if _compass.superview !== self { addSubview(_compass) }
            _compass.frame = CGRect(x: bounds.maxX - safeAreaInsets.right - 8 - 40, y: safeAreaInsets.top + 8, width: 40, height: 40)
            _compass.isHidden = false
        } else if _compass.superview === self { _compass.removeFromSuperview() }
        if showsScale {
            if _scaleView.superview !== self { addSubview(_scaleView) }
            _scaleView.frame = CGRect(x: safeAreaInsets.left + 12, y: safeAreaInsets.top + 8, width: 150, height: 20)
        } else if _scaleView.superview === self { _scaleView.removeFromSuperview() }
        _layoutAnnotations()
    }
    /// sizes the base view: the view's bounds, or when tilted the stretch of plane that perspective brings into view
    /// (taller, reaching toward the horizon, and wider at the far edge), tilted by its layer's 3D transform
    func _layoutBase() {
        let size = bounds.size, mid = CGPoint(x: bounds.midX, y: bounds.midY)
        let t = Double(_pitch) * Double.pi / 180
        if t == 0 || size.height < 1 {
            _base.layer.transform = CATransform3DIdentity
            _base.bounds = CGRect(origin: .zero, size: size)
            _base.center = mid
            _baseAnchor = CGPoint(x: size.width / 2, y: size.height / 2)
        } else {
            let d = _eye, h2 = Double(size.height) / 2
            let top = h2 / (cos(t) - h2 * sin(t) / d)           /* the plane distance shown at the view's top edge */
            let far = 1 + top * sin(t) / d                       /* how much smaller the plane is drawn there */
            let bottom = h2 / (cos(t) + h2 * sin(t) / d)        /* and at its bottom edge (nearer: drawn larger) */
            let w = CGFloat(Double(size.width) * far + 4), above = CGFloat(top + 2), below = CGFloat(bottom + 2)
            _base.layer.transform = CATransform3DIdentity
            _base.bounds = CGRect(x: 0, y: 0, width: w, height: above + below)
            _base.center = mid
            // about the plane origin (not the base's middle): shift it there, then tilt in perspective
            var m = CATransform3DIdentity
            m.m22 = CGFloat(cos(t)); m.m23 = CGFloat(sin(t)); m.m24 = CGFloat(-sin(t) / d)
            m.m32 = CGFloat(-sin(t)); m.m33 = CGFloat(cos(t)); m.m34 = CGFloat(-cos(t) / d)
            _base.layer.transform = CATransform3DConcat(CATransform3DMakeTranslation(0, (above + below) / 2 - above, 0), m)
            _baseAnchor = CGPoint(x: w / 2, y: above)
        }
        _base.setNeedsDisplay()
    }
    open override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        _base.setNeedsDisplay()
    }
    func _layoutAnnotations() {
        let toView = _toView
        let all = (showsUserLocation && userLocation.location != nil ? [userLocation as MKAnnotation] : []) + _annotations
        for a in all {
            guard let v = _views[ObjectIdentifier(a)] else { continue }
            let p = toView(MKMapPoint(a.coordinate))
            let anchor = v._anchor
            v.frame.origin = CGPoint(x: p.x - anchor.x, y: p.y - anchor.y)
            v.isHidden = !bounds.insetBy(dx: -120, dy: -120).contains(p) || (_pitch != 0 && _behindHorizon(a.coordinate))
            if let m = v as? MKMarkerAnnotationView {   /* titles: dark on the map, light on imagery */
                let imagery = [.satellite, .hybrid, .satelliteFlyover, .hybridFlyover].contains(_effectiveType)
                m.titleLabel.textColor = imagery ? .white : .label
            }
        }
        // selected on top, user location above markers
        if let s = _selected, let v = _views[ObjectIdentifier(s)] { _annotationLayer.bringSubviewToFront(v) }
        if let c = _callout, let v = c.owner {
            let want = v.frame.midX - c.bounds.width / 2 + v.calloutOffset.x
            let x = min(max(want, 8), max(8, bounds.width - c.bounds.width - 8))   /* kept on screen; the tail still points at the view */
            c.frame.origin = CGPoint(x: x, y: v.frame.minY - c.bounds.height - 2 + v.calloutOffset.y)
            c.tailX = v.frame.midX + v.calloutOffset.x - x
            _annotationLayer.bringSubviewToFront(c)
        }
    }

    // MARK: annotations
    open var annotations: [MKAnnotation] { (showsUserLocation && userLocation.location != nil ? [userLocation as MKAnnotation] : []) + _annotations }
    open func addAnnotation(_ annotation: MKAnnotation) { addAnnotations([annotation]) }
    open func addAnnotations(_ annotations: [MKAnnotation]) {
        var added: [MKAnnotationView] = []
        for a in annotations where !_annotations.contains(where: { $0 === a }) {
            _annotations.append(a)
            if let v = _makeView(for: a) { added.append(v) }
        }
        _layoutAnnotations()
        if !added.isEmpty { delegate?.mapView(self, didAdd: added) }
    }
    open func removeAnnotation(_ annotation: MKAnnotation) { removeAnnotations([annotation]) }
    open func removeAnnotations(_ annotations: [MKAnnotation]) {
        for a in annotations {
            if a === _selected { deselectAnnotation(a, animated: false) }
            _annotations.removeAll { $0 === a }
            if let v = _views.removeValue(forKey: ObjectIdentifier(a)) {
                v.removeFromSuperview()
                if let id = v.reuseIdentifier { v.prepareForReuse(); _reuse[id, default: []].append(v) }
            }
        }
    }
    open func annotations(in mapRect: MKMapRect) -> Set<AnyHashable> {
        Set(_annotations.filter { mapRect.contains(MKMapPoint($0.coordinate)) }.compactMap { $0 as? NSObject })
    }
    open func view(for annotation: MKAnnotation) -> MKAnnotationView? { _views[ObjectIdentifier(annotation)] }
    open func register(_ viewClass: AnyClass?, forAnnotationViewWithReuseIdentifier identifier: String) {
        if let c = viewClass as? MKAnnotationView.Type { _registered[identifier] = c } else { _registered[identifier] = nil }
    }
    open func dequeueReusableAnnotationView(withIdentifier identifier: String) -> MKAnnotationView? {
        guard var pool = _reuse[identifier], !pool.isEmpty else { return nil }
        let v = pool.removeLast(); _reuse[identifier] = pool
        return v
    }
    open func dequeueReusableAnnotationView(withIdentifier identifier: String, for annotation: MKAnnotation) -> MKAnnotationView {
        if let v = dequeueReusableAnnotationView(withIdentifier: identifier) { v.annotation = annotation; return v }
        guard let cls = _registered[identifier] else {
            NSException(name: "NSInternalInconsistencyException", reason: "unable to dequeue an annotation view with identifier \(identifier) - must register a class", userInfo: nil).raise()
        }
        return cls.init(annotation: annotation, reuseIdentifier: identifier)
    }
    func _makeView(for a: MKAnnotation) -> MKAnnotationView? {
        var v = delegate?.mapView(self, viewFor: a)
        if v == nil {
            if a is MKUserLocation { v = MKUserLocationView(annotation: a, reuseIdentifier: nil) }
            else if let cls = _registered[MKMapViewDefaultAnnotationViewReuseIdentifier] { v = cls.init(annotation: a, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) }
            else { v = MKMarkerAnnotationView(annotation: a, reuseIdentifier: nil) }
        }
        guard let view = v else { return nil }
        if view.annotation !== a { view.annotation = a }
        view.prepareForDisplay()
        _views[ObjectIdentifier(a)] = view
        if a is MKUserLocation { _annotationLayer.addSubview(view) } else { _annotationLayer.insertSubview(view, at: _annotationLayer.subviews.count) }
        return view
    }
    open func showAnnotations(_ annotations: [MKAnnotation], animated: Bool) {
        guard !annotations.isEmpty else { return }
        var r = MKMapRect.null
        for a in annotations { let p = MKMapPoint(a.coordinate); r = r.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0)) }
        let minSize = 2000 * MKMapPointsPerMeterAtLatitude(MKMapPoint(x: r.midX, y: r.midY).coordinate.latitude)
        if r.width < minSize { r = r.insetBy(dx: -(minSize - r.width) / 2, dy: 0) }
        if r.height < minSize { r = r.insetBy(dx: 0, dy: -(minSize - r.height) / 2) }
        setVisibleMapRect(r, edgePadding: UIEdgeInsets(top: 70, left: 40, bottom: 40, right: 40), animated: animated)
    }

    // MARK: selection
    open var selectedAnnotations: [MKAnnotation] {
        get { _selected.map { [$0] } ?? [] }
        set { if let a = newValue.first { selectAnnotation(a, animated: false) } else if let s = _selected { deselectAnnotation(s, animated: false) } }
    }
    open func selectAnnotation(_ annotation: MKAnnotation, animated: Bool) {
        if let s = _selected, s !== annotation { deselectAnnotation(s, animated: animated) }
        guard _selected !== annotation, let v = _views[ObjectIdentifier(annotation)] ?? _makeView(for: annotation) else { return }
        _selected = annotation
        v.setSelected(true, animated: animated)
        if v.canShowCallout, annotation.title.flatMap({ $0 }) != nil {
            let c = _MKCalloutView(for: v)
            for case let ctl as UIControl in [v.leftCalloutAccessoryView, v.rightCalloutAccessoryView].compactMap({ $0 }) {
                ctl.addTarget(self, action: #selector(_accessoryTapped(_:)), for: .touchUpInside)
            }
            _callout = c
            _annotationLayer.addSubview(c)
        }
        _layoutAnnotations()
        delegate?.mapView(self, didSelect: v)
        delegate?.mapView(self, didSelect: annotation)
    }
    open func deselectAnnotation(_ annotation: MKAnnotation?, animated: Bool) {
        guard let s = _selected, annotation == nil || annotation === s else { return }
        _selected = nil
        _callout?.removeFromSuperview(); _callout = nil
        if let v = _views[ObjectIdentifier(s)] {
            v.setSelected(false, animated: animated)
            delegate?.mapView(self, didDeselect: v)
        }
        delegate?.mapView(self, didDeselect: s)
        _layoutAnnotations()
    }
    @objc func _accessoryTapped(_ c: UIControl) {
        guard let s = _selected, let v = _views[ObjectIdentifier(s)] else { return }
        delegate?.mapView(self, annotationView: v, calloutAccessoryControlTapped: c)
    }

    // MARK: overlays
    open var overlays: [MKOverlay] { _overlays }
    open func overlays(in level: MKOverlayLevel) -> [MKOverlay] { _overlays }
    open func addOverlay(_ overlay: MKOverlay) { addOverlays([overlay]) }
    open func addOverlay(_ overlay: MKOverlay, level: MKOverlayLevel) { addOverlays([overlay]) }
    open func addOverlays(_ overlays: [MKOverlay]) {
        var made: [MKOverlayRenderer] = []
        for o in overlays where !_overlays.contains(where: { $0 === o }) {
            _overlays.append(o)
            let r = delegate?.mapView(self, rendererFor: o) ?? MKOverlayRenderer(overlay: o)
            r._onChange = { [weak self] in self?._base.setNeedsDisplay() }
            _renderers[ObjectIdentifier(o)] = r
            made.append(r)
        }
        _base.setNeedsDisplay()
        if !made.isEmpty { delegate?.mapView(self, didAdd: made) }
    }
    open func addOverlays(_ overlays: [MKOverlay], level: MKOverlayLevel) { addOverlays(overlays) }
    open func insertOverlay(_ overlay: MKOverlay, at index: Int) { addOverlay(overlay); _overlays.removeLast(); _overlays.insert(overlay, at: min(index, _overlays.count)) }
    open func insertOverlay(_ overlay: MKOverlay, at index: Int, level: MKOverlayLevel) { insertOverlay(overlay, at: index) }
    open func insertOverlay(_ overlay: MKOverlay, above sibling: MKOverlay) {
        let i = (_overlays.firstIndex { $0 === sibling } ?? _overlays.count - 1) + 1; insertOverlay(overlay, at: i)
    }
    open func insertOverlay(_ overlay: MKOverlay, below sibling: MKOverlay) { insertOverlay(overlay, at: _overlays.firstIndex { $0 === sibling } ?? 0) }
    open func exchangeOverlay(_ overlay1: MKOverlay, with overlay2: MKOverlay) {
        guard let a = _overlays.firstIndex(where: { $0 === overlay1 }), let b = _overlays.firstIndex(where: { $0 === overlay2 }) else { return }
        _overlays.swapAt(a, b); _base.setNeedsDisplay()
    }
    open func removeOverlay(_ overlay: MKOverlay) { removeOverlays([overlay]) }
    open func removeOverlays(_ overlays: [MKOverlay]) {
        for o in overlays { _overlays.removeAll { $0 === o }; _renderers[ObjectIdentifier(o)] = nil }
        _base.setNeedsDisplay()
    }
    open func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? { _renderers[ObjectIdentifier(overlay)] }
    func _overlayRenderers() -> [(MKOverlay, MKOverlayRenderer)] { _overlays.compactMap { o in _renderers[ObjectIdentifier(o)].map { (o, $0) } } }

    // MARK: user location (the simulated Core Location position)
    func _locating(_ on: Bool) {
        if on {
            let m = _location ?? CLLocationManager()
            _location = m
            m.delegate = self
            delegate?.mapViewWillStartLocatingUser(self)
            m.startUpdatingLocation()
            if let l = m.location { _gotLocation(l) }
        } else {
            _location?.stopUpdatingLocation()
            if let v = _views.removeValue(forKey: ObjectIdentifier(userLocation)) { v.removeFromSuperview() }
            delegate?.mapViewDidStopLocatingUser(self)
            _base.setNeedsDisplay()
        }
    }
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        MainActor.assumeIsolated { _gotLocation(l) }
    }
    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { delegate?.mapView(self, didFailToLocateUserWithError: error) }
    }
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            if showsUserLocation, manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.startUpdatingLocation() }
        }
    }
    func _gotLocation(_ l: CLLocation) {
        guard showsUserLocation else { return }
        userLocation.willChangeValue(forKey: "location")
        userLocation.location = l
        userLocation.didChangeValue(forKey: "location")
        _MKUserLocationSource.last = l.coordinate
        if _views[ObjectIdentifier(userLocation)] == nil { _ = _makeView(for: userLocation) }
        _layoutAnnotations()
        _base.setNeedsDisplay()
        delegate?.mapView(self, didUpdate: userLocation)
        _follow()
    }
    func _follow() {
        guard userTrackingMode != .none, let l = userLocation.location else { return }
        let s = _scale > 20 ? 1.2 : _scale   /* following zooms to street level like iOS */
        _apply(center: MKMapPoint(l.coordinate), scale: s, animated: true)
    }

    // MARK: gestures
    var _panStart = MKMapPoint()
    @objc func _pan(_ g: UIPanGestureRecognizer) {
        guard isScrollEnabled else { return }
        switch g.state {
        case .began: _panStart = _center; _gestureBegan()
        case .changed, .ended:
            // the map point under the finger stays under it
            let t = g.translation(in: self), p = g.location(in: self)
            let grabbed = _toMapAt(CGPoint(x: p.x - t.x, y: p.y - t.y), center: _panStart)
            _apply(center: _centerKeeping(grabbed, at: p, scale: _scale), scale: _scale, animated: false)
            if g.state == .ended { _gestureEnded() }
        default: _gestureEnded()
        }
    }
    /// two-finger gestures: what was under the fingers when they came down, and the camera then
    var _twoStart: (point: MKMapPoint, scale: Double, heading: Double, pitch: CGFloat)?
    @objc func _pinch(_ g: UIPinchGestureRecognizer) {
        guard isZoomEnabled else { return }
        _twoFinger(g) { st in (st.scale / Double(max(0.01, g.scale)), nil, nil) }
    }
    @objc func _rotate(_ g: UIRotationGestureRecognizer) {
        guard isRotateEnabled else { return }
        _twoFinger(g) { st in (nil, st.heading - Double(g.rotation) * 180 / Double.pi, nil) }   /* fingers turn clockwise: so does the map */
    }
    @objc func _tilt(_ g: UIPanGestureRecognizer) {
        guard isPitchEnabled else { return }
        _twoFinger(g) { st in (nil, nil, st.pitch - g.translation(in: self).y / 2) }   /* two fingers up tilt the map back */
    }
    func _twoFinger(_ g: UIGestureRecognizer, _ change: ((point: MKMapPoint, scale: Double, heading: Double, pitch: CGFloat)) -> (Double?, Double?, CGFloat?)) {
        switch g.state {
        case .began:
            if _twoStart == nil || !_gesturing { _twoStart = (_toMap(g.location(in: self)), _scale, _heading, _pitch); _gestureBegan() }
        case .changed, .ended:
            guard let st = _twoStart else { return }
            let (sc, hd, pt) = change(st)
            let s = sc ?? _scale, h = hd ?? _heading, t = pt ?? _pitch
            // pinching and turning keep the map point between the fingers where it is
            let c = pt == nil ? _centerKeeping(st.point, at: g.location(in: self), scale: s, heading: h) : _center
            _apply(center: c, scale: s, heading: h, pitch: t, animated: false)
            if g.state == .ended { _gestureEnded() }
        default: _gestureEnded()
        }
    }
    func _gestureBegan() {
        _gesturing = true; _gestureMoved = false
        if userTrackingMode != .none { userTrackingMode = .none }
    }
    func _gestureEnded() {
        guard _gesturing else { return }
        _gesturing = false; _twoStart = nil
        if _gestureMoved { delegate?.mapView(self, regionDidChangeAnimated: false) }
    }
    /// the map point at view point v were the map centred on `center`
    func _toMapAt(_ v: CGPoint, center: MKMapPoint) -> MKMapPoint {
        let p = _toMap(v)
        return MKMapPoint(x: p.x - _center.x + center.x, y: p.y - _center.y + center.y)
    }
    /// the centre that puts map point m at view point v, at this scale and heading (and the current pitch)
    func _centerKeeping(_ m: MKMapPoint, at v: CGPoint, scale: Double, heading: Double? = nil) -> MKMapPoint {
        let (s0, h0) = (_scale, _heading)
        _scale = scale; _heading = heading ?? _heading
        let p = _toMap(v)
        let c = MKMapPoint(x: m.x - (p.x - _center.x), y: m.y - (p.y - _center.y))
        _scale = s0; _heading = h0
        return c
    }
    @objc func _doubleTap(_ g: UITapGestureRecognizer) {
        guard isZoomEnabled else { return }
        let p = g.location(in: self)
        // zoom in 2x keeping the tapped point under the finger
        let s = _scale / 2
        _apply(center: _centerKeeping(_toMap(p), at: p, scale: s), scale: s, animated: true)
    }
    @objc func _tap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: _annotationLayer)
        if let c = _callout, c.frame.contains(p) { return }
        for v in _annotationLayer.subviews.reversed() {
            guard let av = v as? MKAnnotationView, !av.isHidden, av.isEnabled, let a = av.annotation, av._hitFrame.insetBy(dx: -6, dy: -6).contains(p) else { continue }
            if a === _selected { return }
            selectAnnotation(a, animated: true)
            return
        }
        if let s = _selected { deselectAnnotation(s, animated: true) }
    }

    func _behindHorizon(_ c: CLLocationCoordinate2D) -> Bool {
        var dx = MKMapPoint(c).x - _center.x
        if dx < -_MKWorld / 2 { dx += _MKWorld } else if dx > _MKWorld / 2 { dx -= _MKWorld }
        let y = Self._rotate(dx / _scale, (MKMapPoint(c).y - _center.y) / _scale, -_heading * Double.pi / 180).1
        return 1 - y * sin(Double(_pitch) * Double.pi / 180) / _eye < 0.05
    }

    @objc func _isim_dumpText() -> String {
        let r = region
        return String(format: "map center %.5f,%.5f span %.4f,%.4f annotations %d overlays %d type %@", r.center.latitude, r.center.longitude,
                      r.span.latitudeDelta, r.span.longitudeDelta, _annotations.count, _overlays.count, "\(_effectiveType)")
            + (_heading != 0 || _pitch != 0 ? String(format: " heading %.0f pitch %.0f", _heading, Double(_pitch)) : "")
    }
}

/// the map's two-finger gestures recognise together (pinch, rotate and tilt at once)
final class _MKGestureFriend: NSObject, UIGestureRecognizerDelegate {
    @MainActor static let shared = _MKGestureFriend()
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        g.view === other.view && g.view is MKMapView
    }
}

/// an animated camera change, stepped by a display link
@MainActor
final class _MKCameraAnimation: NSObject {
    typealias Camera = (center: MKMapPoint, scale: Double, heading: Double, pitch: CGFloat)
    weak var map: MKMapView?
    let from: Camera, to: Camera
    let start = CACurrentMediaTime(), duration = 0.35
    var link: CADisplayLink?
    init(map: MKMapView, from: Camera, to: Camera) {
        self.map = map; self.from = from; self.to = to
        super.init()
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }
    func stop() { link?.invalidate(); link = nil }
    @objc func step(_ l: CADisplayLink) {
        guard let m = map else { stop(); return }
        let u = min(1, (CACurrentMediaTime() - start) / duration)
        let e = u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2   /* ease in-out */
        var dx = to.center.x - from.center.x
        if dx > _MKWorld / 2 { dx -= _MKWorld } else if dx < -_MKWorld / 2 { dx += _MKWorld }   /* the short way round */
        var dh = to.heading - from.heading
        if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
        var x = from.center.x + dx * e
        x = (x.truncatingRemainder(dividingBy: _MKWorld) + _MKWorld).truncatingRemainder(dividingBy: _MKWorld)
        let c = u >= 1 ? to.center : MKMapPoint(x: x, y: from.center.y + (to.center.y - from.center.y) * e)
        let s = u >= 1 ? to.scale : from.scale * pow(to.scale / from.scale, e)
        let h = u >= 1 ? to.heading : ((from.heading + dh * e).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        m._set(center: c, scale: s, heading: h, pitch: from.pitch + (to.pitch - from.pitch) * CGFloat(e))
        if u >= 1 {
            stop()
            if m._animation === self { m._animation = nil }
            m.delegate?.mapView(m, regionDidChangeAnimated: true)
        }
    }
}
