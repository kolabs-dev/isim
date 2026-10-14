// isim MapKit for Objective-C (sdk-src/Frameworks/MapKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors. Core Location's coordinate and MapKit's geometry types are Swift structs here, so the
// members that take or return them are in MapKit.m, over the _isim_ members below that pass their components.
// MKAnnotation and MKMapViewDelegate are Swift protocols in the overlay (apps built against them keep their witness
// tables): an Objective-C annotation object is wrapped in an _MKObjCAnnotation (its coordinate read through its
// selectors), and an Objective-C delegate in an adapter that sends each call to the selectors the object implements.
import UIKit
import ObjectiveC
@_spi(isim) import CoreLocation

nonisolated(unsafe) private var _mkWrapperKey: UInt8 = 0
nonisolated(unsafe) private var _mkDelegateKey: UInt8 = 0

/// an Objective-C object conforming to <MKAnnotation>, as the overlay's Swift MKAnnotation
final class _MKObjCAnnotation: NSObject, MKAnnotation, @unchecked Sendable {
    let target: NSObject
    init(_ t: NSObject) { target = t }
    deinit { objc_setAssociatedObject(target, &_mkWrapperKey, nil, .OBJC_ASSOCIATION_ASSIGN) }
    var coordinate: CLLocationCoordinate2D {
        let s = NSSelectorFromString("coordinate")
        guard target.responds(to: s) else { return kCLLocationCoordinate2DInvalid }
        // CLLocationCoordinate2D is two doubles, returned like a CGPoint
        typealias Get = @convention(c) (AnyObject, Selector) -> CGPoint
        let p = unsafeBitCast(target.method(for: s), to: Get.self)(target, s)
        return CLLocationCoordinate2D(latitude: p.x, longitude: p.y)
    }
    var title: String? { _string("title") }
    var subtitle: String? { _string("subtitle") }
    private func _string(_ sel: String) -> String? {
        let s = NSSelectorFromString(sel)
        guard target.responds(to: s) else { return nil }
        return target.perform(s)?.takeUnretainedValue() as? String
    }
    override var hash: Int { target.hash }
    override func isEqual(_ object: Any?) -> Bool { (object as? _MKObjCAnnotation)?.target === target || (object as AnyObject?) === target }
}
/// an Objective-C annotation as the overlay's MKAnnotation (the same wrapper each time while it is in use)
func _mkAnnotation(_ o: NSObject) -> MKAnnotation {
    if let a = o as? MKAnnotation { return a }
    if let w = objc_getAssociatedObject(o, &_mkWrapperKey) as? _MKObjCAnnotation { return w }
    let w = _MKObjCAnnotation(o)
    objc_setAssociatedObject(o, &_mkWrapperKey, w, .OBJC_ASSOCIATION_ASSIGN)    // the wrapper holds the object; it clears this
    return w
}
/// the object an Objective-C caller gave for an annotation
func _mkObject(_ a: MKAnnotation) -> NSObject { (a as? _MKObjCAnnotation)?.target ?? (a as! NSObject) }

@discardableResult
func _mkSend(_ target: NSObject?, _ sel: String, _ a: AnyObject?, _ b: AnyObject? = nil, _ c: AnyObject? = nil) -> Bool {
    let s = NSSelectorFromString(sel)
    guard let t = target, t.responds(to: s) else { return false }
    typealias Send = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?) -> Void
    unsafeBitCast(t.method(for: s), to: Send.self)(t, s, a, b, c)
    return true
}

@MainActor final class _MKObjCMapViewDelegate: MKMapViewDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func _bool(_ sel: String, _ map: MKMapView, _ v: Bool) {
        let s = NSSelectorFromString(sel)
        guard let t = target, t.responds(to: s) else { return }
        typealias Send = @convention(c) (AnyObject, Selector, AnyObject, Bool) -> Void
        unsafeBitCast(t.method(for: s), to: Send.self)(t, s, map, v)
    }
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) { _bool("mapView:regionWillChangeAnimated:", mapView, animated) }
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) { _bool("mapView:regionDidChangeAnimated:", mapView, animated) }
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) { _mkSend(target, "mapViewDidChangeVisibleRegion:", mapView) }
    func mapViewWillStartLoadingMap(_ mapView: MKMapView) { _mkSend(target, "mapViewWillStartLoadingMap:", mapView) }
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) { _mkSend(target, "mapViewDidFinishLoadingMap:", mapView) }
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) { _bool("mapViewDidFinishRenderingMap:fullyRendered:", mapView, fullyRendered) }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let s = NSSelectorFromString("mapView:viewForAnnotation:")
        guard let t = target, t.responds(to: s) else { return nil }
        typealias Send = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Unmanaged<AnyObject>?
        return unsafeBitCast(t.method(for: s), to: Send.self)(t, s, mapView, _mkObject(annotation))?.takeUnretainedValue() as? MKAnnotationView
    }
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) { _mkSend(target, "mapView:didAddAnnotationViews:", mapView, views as NSArray) }
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        _mkSend(target, "mapView:annotationView:calloutAccessoryControlTapped:", mapView, view, control)
    }
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) { _mkSend(target, "mapView:didSelectAnnotationView:", mapView, view) }
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) { _mkSend(target, "mapView:didDeselectAnnotationView:", mapView, view) }
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) { _mkSend(target, "mapView:didSelectAnnotation:", mapView, _mkObject(annotation)) }
    func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) { _mkSend(target, "mapView:didDeselectAnnotation:", mapView, _mkObject(annotation)) }
    func mapViewWillStartLocatingUser(_ mapView: MKMapView) { _mkSend(target, "mapViewWillStartLocatingUser:", mapView) }
    func mapViewDidStopLocatingUser(_ mapView: MKMapView) { _mkSend(target, "mapViewDidStopLocatingUser:", mapView) }
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) { _mkSend(target, "mapView:didUpdateUserLocation:", mapView, userLocation) }
    func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
        _mkSend(target, "mapView:didFailToLocateUserWithError:", mapView, error as NSError)
    }
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        let s = NSSelectorFromString("mapView:didChangeUserTrackingMode:animated:")
        guard let t = target, t.responds(to: s) else { return }
        typealias Send = @convention(c) (AnyObject, Selector, AnyObject, Int, Bool) -> Void
        unsafeBitCast(t.method(for: s), to: Send.self)(t, s, mapView, mode.rawValue, animated)
    }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let s = NSSelectorFromString("mapView:rendererForOverlay:")
        if let t = target, t.responds(to: s) {
            typealias Send = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Unmanaged<AnyObject>?
            if let r = unsafeBitCast(t.method(for: s), to: Send.self)(t, s, mapView, overlay)?.takeUnretainedValue() as? MKOverlayRenderer { return r }
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    func mapView(_ mapView: MKMapView, didAdd renderers: [MKOverlayRenderer]) { _mkSend(target, "mapView:didAddOverlayRenderers:", mapView, renderers as NSArray) }
}

// MARK: - the map view

extension MKMapView {
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _MKObjCMapViewDelegate)?.target ?? (delegate as? NSObject) }
        set {
            let a = newValue.map(_MKObjCMapViewDelegate.init)
            objc_setAssociatedObject(self, &_mkDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)   // the delegate is weak
            delegate = a
        }
    }
    @objc(mapType) var _objc_mapType: UInt { get { mapType.rawValue } set { mapType = MKMapType(rawValue: newValue) ?? .standard } }
    @objc(isZoomEnabled) var _objc_isZoomEnabled: Bool { get { isZoomEnabled } set { isZoomEnabled = newValue } }
    @objc(setZoomEnabled:) func _objc_setZoomEnabled(_ v: Bool) { isZoomEnabled = v }
    @objc(isScrollEnabled) var _objc_isScrollEnabled: Bool { get { isScrollEnabled } set { isScrollEnabled = newValue } }
    @objc(setScrollEnabled:) func _objc_setScrollEnabled(_ v: Bool) { isScrollEnabled = v }
    @objc(isRotateEnabled) var _objc_isRotateEnabled: Bool { get { isRotateEnabled } set { isRotateEnabled = newValue } }
    @objc(setRotateEnabled:) func _objc_setRotateEnabled(_ v: Bool) { isRotateEnabled = v }
    @objc(isPitchEnabled) var _objc_isPitchEnabled: Bool { get { isPitchEnabled } set { isPitchEnabled = newValue } }
    @objc(setPitchEnabled:) func _objc_setPitchEnabled(_ v: Bool) { isPitchEnabled = v }
    @objc(showsCompass) var _objc_showsCompass: Bool { get { showsCompass } set { showsCompass = newValue } }
    @objc(showsScale) var _objc_showsScale: Bool { get { showsScale } set { showsScale = newValue } }
    @objc(showsBuildings) var _objc_showsBuildings: Bool { get { showsBuildings } set { showsBuildings = newValue } }
    @objc(showsTraffic) var _objc_showsTraffic: Bool { get { showsTraffic } set { showsTraffic = newValue } }
    @objc(showsPointsOfInterest) var _objc_showsPointsOfInterest: Bool { get { showsPointsOfInterest } set { showsPointsOfInterest = newValue } }
    @objc(showsUserLocation) var _objc_showsUserLocation: Bool { get { showsUserLocation } set { showsUserLocation = newValue } }
    @objc(userLocation) var _objc_userLocation: MKUserLocation { userLocation }
    @objc(isUserLocationVisible) var _objc_isUserLocationVisible: Bool { isUserLocationVisible }
    @objc(userTrackingMode) var _objc_userTrackingMode: Int {
        get { userTrackingMode.rawValue } set { userTrackingMode = MKUserTrackingMode(rawValue: newValue) ?? .none }
    }
    @objc(setUserTrackingMode:animated:) func _objc_setUserTrackingMode(_ mode: Int, animated: Bool) {
        setUserTrackingMode(MKUserTrackingMode(rawValue: mode) ?? .none, animated: animated)
    }
    /// MKCoordinateRegionMakeWithDistance's components
    @objc(_isim_regionWithLatitude:longitude:latitudinalMeters:longitudinalMeters:)
    nonisolated class func _isim_region(_ lat: Double, longitude: Double, latitudinalMeters: Double, longitudinalMeters: Double) -> [Double] {
        let r = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: longitude), latitudinalMeters: latitudinalMeters,
                                   longitudinalMeters: longitudinalMeters)
        return [r.center.latitude, r.center.longitude, r.span.latitudeDelta, r.span.longitudeDelta]
    }
    /// region and center as their components (MapKit.m makes the structs)
    @objc(_isim_region) var _isim_region: [Double] {
        let r = region
        return [r.center.latitude, r.center.longitude, r.span.latitudeDelta, r.span.longitudeDelta]
    }
    @objc(_isim_setRegion:animated:) func _isim_setRegion(_ v: [Double], animated: Bool) {
        guard v.count == 4 else { return }
        setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: v[0], longitude: v[1]),
                                     span: MKCoordinateSpan(latitudeDelta: v[2], longitudeDelta: v[3])), animated: animated)
    }
    @objc(_isim_regionThatFits:) func _isim_regionThatFits(_ v: [Double]) -> [Double] {
        guard v.count == 4 else { return v }
        let r = regionThatFits(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: v[0], longitude: v[1]),
                                                  span: MKCoordinateSpan(latitudeDelta: v[2], longitudeDelta: v[3])))
        return [r.center.latitude, r.center.longitude, r.span.latitudeDelta, r.span.longitudeDelta]
    }
    @objc(_isim_setCenterLatitude:longitude:animated:) func _isim_setCenter(_ lat: Double, longitude: Double, animated: Bool) {
        setCenter(CLLocationCoordinate2D(latitude: lat, longitude: longitude), animated: animated)
    }
    @objc(_isim_convertLatitude:longitude:toPointToView:) func _isim_convert(_ lat: Double, longitude: Double, toPointTo view: UIView?) -> CGPoint {
        convert(CLLocationCoordinate2D(latitude: lat, longitude: longitude), toPointTo: view)
    }
    @objc(_isim_convertPoint:toCoordinateFromView:) func _isim_convert(_ point: CGPoint, toCoordinateFrom view: UIView?) -> CGPoint {
        let c = convert(point, toCoordinateFrom: view)
        return CGPoint(x: c.latitude, y: c.longitude)
    }

    // annotations: Objective-C objects in, the same objects out
    @objc(annotations) var _objc_annotations: [NSObject] { annotations.map(_mkObject) }
    @objc(addAnnotation:) func _objc_addAnnotation(_ a: NSObject) { addAnnotation(_mkAnnotation(a)) }
    @objc(addAnnotations:) func _objc_addAnnotations(_ a: [NSObject]) { addAnnotations(a.map(_mkAnnotation)) }
    @objc(removeAnnotation:) func _objc_removeAnnotation(_ a: NSObject) { removeAnnotation(_mkAnnotation(a)) }
    @objc(removeAnnotations:) func _objc_removeAnnotations(_ a: [NSObject]) { removeAnnotations(a.map(_mkAnnotation)) }
    @objc(viewForAnnotation:) func _objc_view(_ a: NSObject) -> MKAnnotationView? { view(for: _mkAnnotation(a)) }
    @objc(registerClass:forAnnotationViewWithReuseIdentifier:) func _objc_register(_ cls: AnyClass?, identifier: String) {
        register(cls, forAnnotationViewWithReuseIdentifier: identifier)
    }
    @objc(dequeueReusableAnnotationViewWithIdentifier:) func _objc_dequeue(_ identifier: String) -> MKAnnotationView? {
        dequeueReusableAnnotationView(withIdentifier: identifier)
    }
    @objc(dequeueReusableAnnotationViewWithIdentifier:forAnnotation:) func _objc_dequeue(_ identifier: String, for a: NSObject) -> MKAnnotationView {
        dequeueReusableAnnotationView(withIdentifier: identifier, for: _mkAnnotation(a))
    }
    @objc(showAnnotations:animated:) func _objc_show(_ a: [NSObject], animated: Bool) { showAnnotations(a.map(_mkAnnotation), animated: animated) }
    @objc(selectedAnnotations) var _objc_selectedAnnotations: [NSObject] { selectedAnnotations.map(_mkObject) }
    @objc(selectAnnotation:animated:) func _objc_select(_ a: NSObject, animated: Bool) { selectAnnotation(_mkAnnotation(a), animated: animated) }
    @objc(deselectAnnotation:animated:) func _objc_deselect(_ a: NSObject?, animated: Bool) { deselectAnnotation(a.map(_mkAnnotation), animated: animated) }

    // overlays: the overlay's shapes (MKPolyline, MKCircle, ...)
    @objc(overlays) var _objc_overlays: [NSObject] { overlays.compactMap { $0 as? NSObject } }
    @objc(addOverlay:) func _objc_addOverlay(_ o: NSObject) { if let o = o as? MKOverlay { addOverlay(o) } }
    @objc(removeOverlay:) func _objc_removeOverlay(_ o: NSObject) { if let o = o as? MKOverlay { removeOverlay(o) } }
    @objc(rendererForOverlay:) func _objc_renderer(_ o: NSObject) -> MKOverlayRenderer? { (o as? MKOverlay).flatMap { renderer(for: $0) } }
}

// MARK: - annotations and their views

extension MKShape {
    @objc(_isim_latitude) var _isim_latitude: Double { coordinate.latitude }
    @objc(_isim_longitude) var _isim_longitude: Double { coordinate.longitude }
}
extension MKPointAnnotation {
    @objc(_isim_setLatitude:longitude:) func _isim_setCoordinate(_ lat: Double, longitude: Double) {
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: longitude)
    }
}
extension MKUserLocation {
    @objc(_isim_latitude) var _isim_latitude: Double { coordinate.latitude }
    @objc(_isim_longitude) var _isim_longitude: Double { coordinate.longitude }
    @objc(isUpdating) var _objc_isUpdating: Bool { isUpdating }
    @objc(heading) var _objc_heading: CLHeading? { heading }
}
extension MKPlacemark {
    @objc(_isim_initWithLatitude:longitude:addressDictionary:)
    convenience init(_isimLatitude lat: Double, longitude: Double, addressDictionary: [String: Any]?) {
        self.init(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: longitude), addressDictionary: addressDictionary)
    }
    @objc(_isim_latitude) var _isim_latitude: Double { coordinate.latitude }
    @objc(_isim_longitude) var _isim_longitude: Double { coordinate.longitude }
    @objc(countryCode) var _objc_countryCode: String? { countryCode }
}

extension MKAnnotationView {
    @objc(initWithAnnotation:reuseIdentifier:) convenience init(_objcAnnotation a: NSObject?, reuseIdentifier: String?) {
        self.init(annotation: a.map(_mkAnnotation), reuseIdentifier: reuseIdentifier)
    }
    @objc(reuseIdentifier) var _objc_reuseIdentifier: String? { reuseIdentifier }
    @objc(annotation) var _objc_annotation: NSObject? { get { annotation.map(_mkObject) } set { annotation = newValue.map(_mkAnnotation) } }
    @objc(image) var _objc_image: UIImage? { get { image } set { image = newValue } }
    @objc(centerOffset) var _objc_centerOffset: CGPoint { get { centerOffset } set { centerOffset = newValue } }
    @objc(calloutOffset) var _objc_calloutOffset: CGPoint { get { calloutOffset } set { calloutOffset = newValue } }
    @objc(isEnabled) var _objc_isEnabled: Bool { get { isEnabled } set { isEnabled = newValue } }
    @objc(setEnabled:) func _objc_setEnabled(_ v: Bool) { isEnabled = v }
    @objc(isHighlighted) var _objc_isHighlighted: Bool { get { isHighlighted } set { isHighlighted = newValue } }
    @objc(setHighlighted:) func _objc_setHighlighted(_ v: Bool) { isHighlighted = v }
    @objc(isSelected) var _objc_isSelected: Bool { get { isSelected } set { isSelected = newValue } }
    @objc(setSelected:) func _objc_setSelected(_ v: Bool) { isSelected = v }
    @objc(setSelected:animated:) func _objc_setSelected(_ v: Bool, animated: Bool) { setSelected(v, animated: animated) }
    @objc(canShowCallout) var _objc_canShowCallout: Bool { get { canShowCallout } set { canShowCallout = newValue } }
    @objc(leftCalloutAccessoryView) var _objc_left: UIView? { get { leftCalloutAccessoryView } set { leftCalloutAccessoryView = newValue } }
    @objc(rightCalloutAccessoryView) var _objc_right: UIView? { get { rightCalloutAccessoryView } set { rightCalloutAccessoryView = newValue } }
    @objc(detailCalloutAccessoryView) var _objc_detail: UIView? { get { detailCalloutAccessoryView } set { detailCalloutAccessoryView = newValue } }
    @objc(isDraggable) var _objc_isDraggable: Bool { get { isDraggable } set { isDraggable = newValue } }
    @objc(setDraggable:) func _objc_setDraggable(_ v: Bool) { isDraggable = v }
    @objc(clusteringIdentifier) var _objc_clusteringIdentifier: String? { get { clusteringIdentifier } set { clusteringIdentifier = newValue } }
    @objc(displayPriority) var _objc_displayPriority: Float {
        get { displayPriority.rawValue } set { displayPriority = MKFeatureDisplayPriority(rawValue: newValue) }
    }
    @objc(prepareForReuse) func _objc_prepareForReuse() { prepareForReuse() }
}
extension MKMarkerAnnotationView {
    @objc(markerTintColor) var _objc_markerTintColor: UIColor? { get { markerTintColor } set { markerTintColor = newValue } }
    @objc(glyphTintColor) var _objc_glyphTintColor: UIColor? { get { glyphTintColor } set { glyphTintColor = newValue } }
    @objc(glyphText) var _objc_glyphText: String? { get { glyphText } set { glyphText = newValue } }
    @objc(glyphImage) var _objc_glyphImage: UIImage? { get { glyphImage } set { glyphImage = newValue } }
    @objc(selectedGlyphImage) var _objc_selectedGlyphImage: UIImage? { get { selectedGlyphImage } set { selectedGlyphImage = newValue } }
    @objc(titleVisibility) var _objc_titleVisibility: Int {
        get { titleVisibility.rawValue } set { titleVisibility = MKFeatureVisibility(rawValue: newValue) ?? .adaptive }
    }
    @objc(subtitleVisibility) var _objc_subtitleVisibility: Int {
        get { subtitleVisibility.rawValue } set { subtitleVisibility = MKFeatureVisibility(rawValue: newValue) ?? .adaptive }
    }
    @objc(animatesWhenAdded) var _objc_animatesWhenAdded: Bool { get { animatesWhenAdded } set { animatesWhenAdded = newValue } }
}
extension MKPinAnnotationView {
    @objc(pinTintColor) var _objc_pinTintColor: UIColor? { get { pinTintColor } set { pinTintColor = newValue } }
    @objc(animatesDrop) var _objc_animatesDrop: Bool { get { animatesDrop } set { animatesDrop = newValue } }
    @objc(redPinColor) class func _objc_red() -> UIColor { redPinColor() }
    @objc(greenPinColor) class func _objc_green() -> UIColor { greenPinColor() }
    @objc(purplePinColor) class func _objc_purple() -> UIColor { purplePinColor() }
}

// MARK: - map items and local search

extension MKMapItem {
    @objc(initWithPlacemark:) convenience init(_objcPlacemark p: MKPlacemark) { self.init(placemark: p) }
    @objc(mapItemForCurrentLocation) class func _objc_current() -> MKMapItem { forCurrentLocation() }
    @objc(placemark) var _objc_placemark: MKPlacemark { placemark }
    @objc(isCurrentLocation) var _objc_isCurrentLocation: Bool { isCurrentLocation }
    @objc(name) var _objc_name: String? { get { name } set { name = newValue } }
    @objc(phoneNumber) var _objc_phoneNumber: String? { get { phoneNumber } set { phoneNumber = newValue } }
    @objc(url) var _objc_url: URL? { get { url } set { url = newValue } }
    @objc(timeZone) var _objc_timeZone: TimeZone? { get { timeZone } set { timeZone = newValue } }
    @objc(pointOfInterestCategory) var _objc_category: String? {
        get { pointOfInterestCategory?.rawValue } set { pointOfInterestCategory = newValue.map { MKPointOfInterestCategory(rawValue: $0) } }
    }
}

extension MKLocalSearch.Request {
    @objc(initWithNaturalLanguageQuery:) convenience init(_objcQuery q: String) { self.init(naturalLanguageQuery: q) }
    @objc(naturalLanguageQuery) var _objc_naturalLanguageQuery: String? { get { naturalLanguageQuery } set { naturalLanguageQuery = newValue } }
    @objc(resultTypes) var _objc_resultTypes: UInt { get { resultTypes.rawValue } set { resultTypes = ResultType(rawValue: newValue) } }
    @objc(_isim_region) var _isim_region: [Double] {
        [region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta]
    }
    @objc(_isim_setRegion:) func _isim_setRegion(_ v: [Double]) {
        guard v.count == 4 else { return }
        region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: v[0], longitude: v[1]),
                                    span: MKCoordinateSpan(latitudeDelta: v[2], longitudeDelta: v[3]))
    }
}
extension MKLocalSearch.Response {
    @objc(mapItems) var _objc_mapItems: [MKMapItem] { mapItems }
    @objc(_isim_boundingRegion) var _isim_boundingRegion: [Double] {
        [boundingRegion.center.latitude, boundingRegion.center.longitude, boundingRegion.span.latitudeDelta, boundingRegion.span.longitudeDelta]
    }
}
extension MKLocalSearch {
    @objc(initWithRequest:) convenience init(_objcRequest r: Request) { self.init(request: r) }
    @objc(isSearching) var _objc_isSearching: Bool { isSearching }
    @objc(startWithCompletionHandler:)
    func _objc_start(_ completionHandler: @escaping @convention(block) (Response?, NSError?) -> Void) {
        start { r, e in completionHandler(r, e.map { $0 as NSError }) }
    }
    @objc(cancel) func _objc_cancel() { cancel() }
}

// MARK: - overlays

extension MKMultiPoint {
    @objc(pointCount) var _objc_pointCount: Int { pointCount }
    /// latitude, longitude pairs
    @objc(_isim_coordinates) var _isim_coordinates: [Double] {
        var c = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&c, range: NSRange(location: 0, length: pointCount))
        return c.flatMap { [$0.latitude, $0.longitude] }
    }
}
extension MKPolyline {
    @objc(_isim_polylineWithCoordinates:) class func _isim_polyline(_ v: [Double]) -> MKPolyline {
        let c = stride(from: 0, to: v.count - 1, by: 2).map { CLLocationCoordinate2D(latitude: v[$0], longitude: v[$0 + 1]) }
        return MKPolyline(coordinates: c, count: c.count)
    }
}
extension MKPolygon {
    @objc(_isim_polygonWithCoordinates:) class func _isim_polygon(_ v: [Double]) -> MKPolygon {
        let c = stride(from: 0, to: v.count - 1, by: 2).map { CLLocationCoordinate2D(latitude: v[$0], longitude: v[$0 + 1]) }
        return MKPolygon(coordinates: c, count: c.count)
    }
}
extension MKCircle {
    @objc(_isim_circleWithLatitude:longitude:radius:) class func _isim_circle(_ lat: Double, longitude: Double, radius: Double) -> MKCircle {
        MKCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: longitude), radius: radius)
    }
    @objc(radius) var _objc_radius: Double { radius }
}
extension MKOverlayRenderer {
    @objc(initWithOverlay:) convenience init(_objcOverlay o: NSObject) { self.init(overlay: o as! MKOverlay) }
    @objc(overlay) var _objc_overlay: NSObject? { overlay as? NSObject }
    @objc(alpha) var _objc_alpha: CGFloat { get { alpha } set { alpha = newValue } }
    @objc(setNeedsDisplay) func _objc_setNeedsDisplay() { setNeedsDisplay() }
}
extension MKOverlayPathRenderer {
    @objc(fillColor) var _objc_fillColor: UIColor? { get { fillColor } set { fillColor = newValue } }
    @objc(strokeColor) var _objc_strokeColor: UIColor? { get { strokeColor } set { strokeColor = newValue } }
    @objc(lineWidth) var _objc_lineWidth: CGFloat { get { lineWidth } set { lineWidth = newValue } }
    @objc(lineDashPattern) var _objc_lineDashPattern: [NSNumber]? { get { lineDashPattern } set { lineDashPattern = newValue } }
}
extension MKPolylineRenderer {
    @objc(initWithPolyline:) convenience init(_objcPolyline p: MKPolyline) { self.init(polyline: p) }
    @objc(polyline) var _objc_polyline: MKPolyline { polyline }
}
extension MKPolygonRenderer {
    @objc(initWithPolygon:) convenience init(_objcPolygon p: MKPolygon) { self.init(polygon: p) }
    @objc(polygon) var _objc_polygon: MKPolygon { polygon }
}
extension MKCircleRenderer {
    @objc(initWithCircle:) convenience init(_objcCircle c: MKCircle) { self.init(circle: c) }
    @objc(circle) var _objc_circle: MKCircle { circle }
}
