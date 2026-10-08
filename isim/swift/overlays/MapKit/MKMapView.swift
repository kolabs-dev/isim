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
    open var altitude: CLLocationDistance { get { centerCoordinateDistance } set { centerCoordinateDistance = newValue } }
    public override init() { super.init() }
    public convenience init(lookingAtCenter centerCoordinate: CLLocationCoordinate2D, fromDistance distance: CLLocationDistance, pitch: CGFloat, heading: CLLocationDirection) {
        self.init(); self.centerCoordinate = centerCoordinate; centerCoordinateDistance = distance; self.pitch = pitch; self.heading = heading
    }
    public convenience init(lookingAtCenter centerCoordinate: CLLocationCoordinate2D, fromEyeCoordinate eye: CLLocationCoordinate2D, eyeAltitude: CLLocationDistance) {
        self.init(); self.centerCoordinate = centerCoordinate; centerCoordinateDistance = eyeAltitude
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

/// the basemap layer
final class _MKBaseView: UIView {
    weak var map: MKMapView?
    override func draw(_ rect: CGRect) {
        guard let m = map else { return }
        let dark = traitCollection.userInterfaceStyle == .dark
        _MKBasemap.draw(visible: m.visibleMapRect, scale: m._scale, rect: bounds, type: m._effectiveType, dark: dark,
                        showsLabels: m.pointOfInterestFilter.map { $0.includes(.landmark) } ?? true, toView: m._toView)
        // overlays (above the basemap, below annotations)
        for (o, r) in m._overlayRenderers() where o.intersects(m.visibleMapRect.insetBy(dx: -m.visibleMapRect.width, dy: -m.visibleMapRect.height)) {
            r._draw(toView: m._toView, scale: CGFloat(m._scale), visible: m.visibleMapRect)
        }
        if m.showsUserLocation, let loc = m.userLocation.location, loc.horizontalAccuracy > 0 {
            let c = m._toView(MKMapPoint(loc.coordinate))
            let r = CGFloat(loc.horizontalAccuracy * MKMapPointsPerMeterAtLatitude(loc.coordinate.latitude) / m._scale)
            if r > 14 {
                UIColor.systemBlue.withAlphaComponent(0.12).setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()
            }
        }
        // attribution (isim has no map data provider)
        let note = _MKBasemap.usesTiles ? "isim map · tiles from local cache" : "isim map · offline basemap"
        _MKBasemap._text(note, at: CGPoint(x: 10, y: bounds.maxY - 18 - m.layoutMargins.bottom * 0), font: .systemFont(ofSize: 10, weight: .medium),
                         color: UIColor.secondaryLabel, halo: m._effectiveType == .standard || m._effectiveType == .mutedStandard ? UIColor.systemBackground : nil)
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
    open var showsCompass = true
    open var showsScale = false
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
    let _compass = UIView()

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
        addSubview(_base)
        addSubview(_annotationLayer)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(_pan(_:)))
        addGestureRecognizer(pan)
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
            return MKMapRect(x: _center.x - w / 2, y: _center.y - h / 2, width: w, height: h)
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
    var _heading: CLLocationDirection = 0, _pitch: CGFloat = 0
    open func setCamera(_ camera: MKMapCamera, animated: Bool) {
        if bounds.width < 1 || bounds.height < 1 { _pendingFit = { [weak self] in self?.setCamera(camera, animated: animated) } } else { _pendingFit = nil }
        _heading = camera.heading; _pitch = camera.pitch
        let metersTall = camera.centerCoordinateDistance * 2 * tan(15 * Double.pi / 180)
        let s = metersTall * MKMapPointsPerMeterAtLatitude(camera.centerCoordinate.latitude) / Double(_sizeForFit().height)
        _apply(center: MKMapPoint(camera.centerCoordinate), scale: s, animated: animated)
    }
    open func setCameraZoomRange(_ range: MKMapCameraZoomRange?, animated: Bool) { cameraZoomRange = range }
    open func setCameraBoundary(_ boundary: MKMapCameraBoundary?, animated: Bool) { cameraBoundary = boundary }

    /// a camera change made before the view has a size: redone once it has one (the fit depends on the size)
    var _pendingFit: (() -> Void)?
    var _gesturing = false, _gestureMoved = false
    func _apply(center: MKMapPoint, scale: Double, animated: Bool) {
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
        _initialRegionSet = true
        let changed = abs(c.x - _center.x) > 1e-6 || abs(c.y - _center.y) > 1e-6 || abs(s - _scale) > 1e-9
        guard changed else { return }
        if !_gesturing || !_gestureMoved { delegate?.mapView(self, regionWillChangeAnimated: animated) }
        if _gesturing { _gestureMoved = true }
        _center = c; _scale = s
        _regionChanged()
        delegate?.mapViewDidChangeVisibleRegion(self)
        if !_gesturing { delegate?.mapView(self, regionDidChangeAnimated: animated) }   /* a drag reports it once, at the end */
    }
    func _regionChanged() {
        _base.setNeedsDisplay()
        setNeedsLayout()
        _layoutAnnotations()
    }
    var _toView: (MKMapPoint) -> CGPoint {
        let vr = visibleMapRect, s = _scale
        return { p in
            var dx = p.x - vr.minX
            // wrap around the 180th meridian to the copy nearest the view
            if dx < -_MKWorld / 2 { dx += _MKWorld } else if dx > _MKWorld / 2 + vr.width { dx -= _MKWorld }
            return CGPoint(x: dx / s, y: (p.y - vr.minY) / s)
        }
    }
    open func convert(_ coordinate: CLLocationCoordinate2D, toPointTo view: UIView?) -> CGPoint {
        let p = _toView(MKMapPoint(coordinate))
        return view.map { convert(p, to: $0) } ?? p
    }
    open func convert(_ point: CGPoint, toCoordinateFrom view: UIView?) -> CLLocationCoordinate2D {
        let p = view.map { convert(point, from: $0) } ?? point
        let vr = visibleMapRect
        return MKMapPoint(x: vr.minX + Double(p.x) * _scale, y: vr.minY + Double(p.y) * _scale).coordinate
    }
    open func convert(_ region: MKCoordinateRegion, toRectTo view: UIView?) -> CGRect {
        let r = _MKMapRect(for: region)
        let a = _toView(r.origin)
        let rect = CGRect(x: a.x, y: a.y, width: r.width / _scale, height: r.height / _scale)
        return view.map { convert(rect, to: $0) } ?? rect
    }
    open func convert(_ rect: CGRect, toRegionFrom view: UIView?) -> MKCoordinateRegion {
        let r = view.map { convert(rect, from: $0) } ?? rect
        let vr = visibleMapRect
        return MKCoordinateRegionForMapRect(MKMapRect(x: vr.minX + Double(r.minX) * _scale, y: vr.minY + Double(r.minY) * _scale,
                                                      width: Double(r.width) * _scale, height: Double(r.height) * _scale))
    }

    // MARK: layout
    open override func layoutSubviews() {
        super.layoutSubviews()
        if _base.frame != bounds { _base.frame = bounds; _annotationLayer.frame = bounds; _base.setNeedsDisplay() }
        if bounds.width >= 1, bounds.height >= 1, let f = _pendingFit { _pendingFit = nil; f() }
        _layoutAnnotations()
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
            v.isHidden = !bounds.insetBy(dx: -120, dy: -120).contains(p)
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
        case .began: _panStart = _center; _gesturing = true; _gestureMoved = false; if userTrackingMode != .none { userTrackingMode = .none }
        case .changed, .ended:
            let t = g.translation(in: self)
            _apply(center: MKMapPoint(x: _panStart.x - Double(t.x) * _scale, y: _panStart.y - Double(t.y) * _scale), scale: _scale, animated: false)
            if g.state == .ended { _gesturing = false; if _gestureMoved { delegate?.mapView(self, regionDidChangeAnimated: false) } }
        default: _gesturing = false
        }
    }
    @objc func _doubleTap(_ g: UITapGestureRecognizer) {
        guard isZoomEnabled else { return }
        let p = g.location(in: self)
        let target = convert(p, toCoordinateFrom: self)
        // zoom in 2x keeping the tapped point under the finger
        let tp = MKMapPoint(target), s = _scale / 2
        let c = MKMapPoint(x: tp.x - Double(p.x - bounds.midX) * s, y: tp.y - Double(p.y - bounds.midY) * s)
        _apply(center: c, scale: s, animated: true)
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

    @objc func _isim_dumpText() -> String {
        let r = region
        return String(format: "map center %.5f,%.5f span %.4f,%.4f annotations %d overlays %d type %@", r.center.latitude, r.center.longitude,
                      r.span.latitudeDelta, r.span.longitudeDelta, _annotations.count, _overlays.count, "\(_effectiveType)")
    }
}
