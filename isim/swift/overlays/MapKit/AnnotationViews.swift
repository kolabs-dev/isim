// isim MapKit: annotation views — MKAnnotationView (image), MKMarkerAnnotationView (iOS balloon markers with
// glyph and title), MKPinAnnotationView, the user-location dot, the callout bubble — and overlay renderers.
import UIKit

@objc(MKAnnotationView) open class MKAnnotationView: UIView {
    public enum DragState: UInt, Sendable { case none = 0, starting, dragging, canceling, ending }
    public enum CollisionMode: Int, Sendable { case rectangle = 0, circle, none }
    public struct ZPriority: RawRepresentable, Hashable, Sendable {
        public let rawValue: Float
        public init(rawValue: Float) { self.rawValue = rawValue }
        public static let defaultUnselected = ZPriority(rawValue: 500), defaultSelected = ZPriority(rawValue: 1000)
        public static let min = ZPriority(rawValue: 0), max = ZPriority(rawValue: 1000)
    }
    open private(set) var reuseIdentifier: String?
    open var annotation: MKAnnotation? { didSet { annotationChanged() } }
    open var image: UIImage? { didSet { if let i = image { bounds.size = i.size }; setNeedsDisplay() } }
    open var centerOffset: CGPoint = .zero
    open var calloutOffset: CGPoint = .zero
    open var isEnabled = true
    open var isHighlighted = false
    open var isSelected: Bool { get { _selected } set { setSelected(newValue, animated: false) } }
    var _selected = false
    open var canShowCallout = false
    open var leftCalloutAccessoryView: UIView?
    open var rightCalloutAccessoryView: UIView?
    open var detailCalloutAccessoryView: UIView?
    open var isDraggable = false
    /// changes go to the map's delegate (`mapView(_:annotationView:didChange:fromOldState:)`), as MapKit observes it
    open var dragState: DragState = .none { didSet { if dragState != oldValue { _map?._dragStateChanged(self, from: oldValue) } } }
    open var clusteringIdentifier: String?
    open var displayPriority: MKFeatureDisplayPriority = .required
    open var zPriority: ZPriority = .defaultUnselected
    open var selectedZPriority: ZPriority = .defaultSelected
    open var collisionMode: CollisionMode = .rectangle
    open weak var cluster: MKAnnotationView?

    public required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        self.annotation = annotation
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        backgroundColor = .clear
        annotationChanged()
    }
    public override convenience init(frame: CGRect) { self.init(annotation: nil, reuseIdentifier: nil); self.frame = frame }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open func prepareForReuse() {}
    open func prepareForDisplay() {}
    open func setSelected(_ selected: Bool, animated: Bool) { _selected = selected; setNeedsDisplay(); setNeedsLayout() }
    /// adapted from MapKit: starting goes on to dragging, ending and canceling go back to none (the map lifts the view
    /// while it is dragged; a subclass that overrides this moves through the states itself)
    open func setDragState(_ newDragState: DragState, animated: Bool) {
        switch newDragState {
        case .starting:
            dragState = .starting
            if dragState == .starting { dragState = .dragging }
        case .ending, .canceling:
            dragState = newDragState
            if dragState == newDragState { dragState = .none }
        default:
            dragState = newDragState
        }
    }
    /// the map view showing this view (its annotation layer's superview)
    var _map: MKMapView? { superview?.superview as? MKMapView }
    func annotationChanged() { setNeedsDisplay() }
    open override func draw(_ rect: CGRect) { image?.draw(in: bounds) }
    /// the point of the view that sits on the annotation's coordinate (view coordinates)
    var _anchor: CGPoint { CGPoint(x: bounds.midX - centerOffset.x, y: bounds.midY - centerOffset.y) }
    /// where touches select this view (map coordinates)
    var _hitFrame: CGRect { frame }
    @objc func _isim_dumpText() -> String {
        let a = annotation
        var s = "\(type(of: self)) \(a?.title.flatMap { $0 } ?? "")"
        if let c = a?.coordinate { s += String(format: " @ %.5f,%.5f", c.latitude, c.longitude) }
        if _selected { s += " selected" }
        if let c = a as? MKClusterAnnotation { s += " cluster \(c.memberAnnotations.count)" }
        if dragState != .none { s += " drag \(dragState)" }
        return s
    }
}

public struct MKFeatureDisplayPriority: RawRepresentable, Hashable, Sendable {
    public let rawValue: Float
    public init(rawValue: Float) { self.rawValue = rawValue }
    public static let required = MKFeatureDisplayPriority(rawValue: 1000), defaultHigh = MKFeatureDisplayPriority(rawValue: 750), defaultLow = MKFeatureDisplayPriority(rawValue: 250)
}
public enum MKFeatureVisibility: Int, Sendable { case adaptive = 0, hidden, visible }

/// iOS 11+ marker: a balloon in markerTintColor with a white glyph; the title sits below it.
@objc(MKMarkerAnnotationView) open class MKMarkerAnnotationView: MKAnnotationView {
    open var markerTintColor: UIColor? { didSet { setNeedsDisplay() } }
    open var glyphTintColor: UIColor? { didSet { setNeedsDisplay() } }
    open var glyphText: String? { didSet { setNeedsDisplay() } }
    open var glyphImage: UIImage? { didSet { setNeedsDisplay() } }
    open var selectedGlyphImage: UIImage?
    open var titleVisibility: MKFeatureVisibility = .adaptive { didSet { updateTitle() } }
    open var subtitleVisibility: MKFeatureVisibility = .adaptive
    open var animatesWhenAdded = false
    let titleLabel = UILabel()
    static let small = CGSize(width: 30, height: 38), big = CGSize(width: 44, height: 56)

    public required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
        layoutMarker()
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    override func annotationChanged() { super.annotationChanged(); updateTitle() }
    func updateTitle() {
        titleLabel.text = annotation?.title.flatMap { $0 }
        titleLabel.isHidden = titleVisibility == .hidden || (titleLabel.text ?? "").isEmpty
        layoutMarker()
    }
    open override func setSelected(_ selected: Bool, animated: Bool) { super.setSelected(selected, animated: animated); layoutMarker() }
    var balloon: CGSize { _selected ? MKMarkerAnnotationView.big : MKMarkerAnnotationView.small }
    func layoutMarker() {
        let b = balloon
        bounds = CGRect(x: 0, y: 0, width: b.width, height: b.height)
        centerOffset = CGPoint(x: 0, y: -b.height / 2)      /* the balloon's tip on the coordinate */
        titleLabel.sizeToFit()
        let w = min(140, titleLabel.bounds.width)
        titleLabel.frame = CGRect(x: (b.width - w) / 2, y: b.height + 1, width: w, height: 15)
        superview?.setNeedsLayout()
        setNeedsDisplay()
    }
    override var _hitFrame: CGRect {
        titleLabel.isHidden ? frame : frame.union(titleLabel.frame.offsetBy(dx: frame.minX, dy: frame.minY))
    }
    open override func draw(_ rect: CGRect) {
        let b = balloon, r = b.width / 2
        let tint = markerTintColor ?? .systemRed
        // drop shadow, balloon (circle + tail to the tip)
        let c = CGPoint(x: b.width / 2, y: r)
        func balloonPath(_ dy: CGFloat) -> UIBezierPath {
        let c = CGPoint(x: c.x, y: c.y + dy)
        let path = UIBezierPath()
        path.addArc(withCenter: c, radius: r - 1, startAngle: .pi * 0.78, endAngle: .pi * 0.22, clockwise: true)
        path.addQuadCurve(to: CGPoint(x: b.width / 2, y: b.height - 1 + dy), controlPoint: CGPoint(x: b.width / 2 + r * 0.28, y: b.height - r * 0.55 + dy))
        path.addQuadCurve(to: CGPoint(x: c.x + (r - 1) * cos(.pi * 0.78), y: c.y + (r - 1) * sin(.pi * 0.78)),
                          controlPoint: CGPoint(x: b.width / 2 - r * 0.28, y: b.height - r * 0.55))
        path.close()
        return path
        }
        UIColor.black.withAlphaComponent(0.18).setFill()
        balloonPath(1).fill()
        tint.setFill()
        balloonPath(0).fill()
        // glyph
        let g = glyphTintColor ?? .white
        let gs = r * 1.0
        let gr = CGRect(x: c.x - gs / 2, y: c.y - gs / 2, width: gs, height: gs)
        if let img = (_selected ? selectedGlyphImage : nil) ?? glyphImage {
            img.withTintColor(g).draw(in: gr)
        } else if let t = glyphText ?? (annotation as? MKClusterAnnotation).map({ "\($0.memberAnnotations.count)" }), !t.isEmpty {
            let f = UIFont.systemFont(ofSize: r * 0.9, weight: .bold)
            let s = (t as NSString).size(withAttributes: [.font: f])
            (t as NSString).draw(at: CGPoint(x: c.x - s.width / 2, y: c.y - s.height / 2), withAttributes: [.font: f, .foregroundColor: g])
        } else {
            // default glyph: a map pin (circle head + stem)
            g.setFill()
            UIBezierPath(ovalIn: CGRect(x: c.x - r * 0.26, y: c.y - r * 0.5, width: r * 0.52, height: r * 0.52)).fill()
            UIBezierPath(roundedRect: CGRect(x: c.x - r * 0.06, y: c.y - r * 0.05, width: r * 0.12, height: r * 0.5), cornerRadius: r * 0.06).fill()
        }
    }
}

@available(iOS, deprecated: 16.0, message: "Use MKMarkerAnnotationView")
@objc(MKPinAnnotationView) open class MKPinAnnotationView: MKAnnotationView {
    public static func redPinColor() -> UIColor { .systemRed }
    public static func greenPinColor() -> UIColor { .systemGreen }
    public static func purplePinColor() -> UIColor { .systemPurple }
    open var pinTintColor: UIColor! = .systemRed { didSet { setNeedsDisplay() } }
    open var animatesDrop = false
    public required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        bounds = CGRect(x: 0, y: 0, width: 16, height: 39)
        centerOffset = CGPoint(x: 0, y: -19.5)
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func draw(_ rect: CGRect) {
        UIColor.darkGray.setFill()
        UIBezierPath(roundedRect: CGRect(x: 7, y: 14, width: 2, height: 25), cornerRadius: 1).fill()
        (pinTintColor ?? .systemRed).setFill()
        UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 14, height: 14)).fill()
        UIColor.white.withAlphaComponent(0.6).setFill()
        UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 4, height: 4)).fill()
    }
}

/// The blue user-location dot with its white ring and the accuracy halo.
open class MKUserLocationView: MKAnnotationView {
    var accuracyRadius: CGFloat = 0
    public required init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        bounds = CGRect(x: 0, y: 0, width: 22, height: 22)
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func draw(_ rect: CGRect) {
        UIColor.black.withAlphaComponent(0.15).setFill()
        UIBezierPath(ovalIn: bounds.offsetBy(dx: 0, dy: 1)).fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: bounds).fill()
        UIColor.systemBlue.setFill()
        UIBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).fill()
    }
}

/// The callout bubble of a selected annotation view with canShowCallout.
final class _MKCalloutView: UIView {
    let title = UILabel(), subtitle = UILabel()
    var left: UIView?, right: UIView?
    var tailX: CGFloat = -1 { didSet { if tailX != oldValue { setNeedsDisplay() } } }
    weak var owner: MKAnnotationView?
    init(for v: MKAnnotationView) {
        owner = v
        super.init(frame: .zero)
        backgroundColor = .clear
        title.font = .systemFont(ofSize: 17, weight: .semibold); title.textColor = .label
        subtitle.font = .systemFont(ofSize: 13); subtitle.textColor = .secondaryLabel
        title.text = v.annotation?.title.flatMap { $0 }
        subtitle.text = v.annotation?.subtitle.flatMap { $0 }
        addSubview(title); addSubview(subtitle)
        left = v.leftCalloutAccessoryView; right = v.rightCalloutAccessoryView
        for a in [left, right].compactMap({ $0 }) { addSubview(a) }
        accessibilityIdentifier = "map-callout"
        layoutNow()
    }
    required init?(coder: NSCoder) { fatalError() }
    func layoutNow() {
        title.sizeToFit(); subtitle.sizeToFit()
        let hasSub = !(subtitle.text ?? "").isEmpty
        let textW = min(240, max(title.bounds.width, subtitle.bounds.width))
        let lw = left.map { $0.bounds.width + 8 } ?? 0, rw = right.map { $0.bounds.width + 8 } ?? 0
        let h: CGFloat = hasSub ? 56 : 44
        bounds = CGRect(x: 0, y: 0, width: max(80, textW + lw + rw + 28), height: h + 10)
        let x = 14 + lw
        title.frame = CGRect(x: x, y: hasSub ? 8 : 12, width: textW, height: 21)
        subtitle.frame = CGRect(x: x, y: 30, width: textW, height: 17)
        subtitle.isHidden = !hasSub
        if let l = left { l.frame.origin = CGPoint(x: 10, y: (h - l.bounds.height) / 2) }
        if let r = right { r.frame.origin = CGPoint(x: bounds.width - 10 - r.bounds.width, y: (h - r.bounds.height) / 2) }
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        let h = bounds.height - 10
        let body = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: bounds.width, height: h), cornerRadius: 12)
        let tail = UIBezierPath()
        let tx = tailX < 0 ? bounds.midX : min(max(tailX, 22), bounds.width - 22)
        tail.move(to: CGPoint(x: tx - 10, y: h - 0.5)); tail.addLine(to: CGPoint(x: tx, y: h + 9)); tail.addLine(to: CGPoint(x: tx + 10, y: h - 0.5)); tail.close()
        UIColor.black.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: CGRect(x: 0, y: 1.5, width: bounds.width, height: h), cornerRadius: 12).fill()
        UIColor.systemBackground.setFill()
        body.fill(); tail.fill()
    }
}

// MARK: - overlay renderers

@objc(MKOverlayRenderer) open class MKOverlayRenderer: NSObject {
    public let overlay: MKOverlay
    open var alpha: CGFloat = 1
    open var contentScaleFactor: CGFloat { UIScreen.main.scale }
    public init(overlay: MKOverlay) { self.overlay = overlay; super.init() }
    /// renderer coordinates = map points relative to the overlay's bounding rect
    open func point(for mapPoint: MKMapPoint) -> CGPoint {
        let o = overlay.boundingMapRect.origin
        return CGPoint(x: mapPoint.x - o.x, y: mapPoint.y - o.y)
    }
    open func mapPoint(for point: CGPoint) -> MKMapPoint {
        let o = overlay.boundingMapRect.origin
        return MKMapPoint(x: Double(point.x) + o.x, y: Double(point.y) + o.y)
    }
    open func rect(for mapRect: MKMapRect) -> CGRect {
        let p = point(for: mapRect.origin); return CGRect(x: p.x, y: p.y, width: mapRect.width, height: mapRect.height)
    }
    open func mapRect(for rect: CGRect) -> MKMapRect {
        let p = mapPoint(for: rect.origin); return MKMapRect(x: p.x, y: p.y, width: Double(rect.width), height: Double(rect.height))
    }
    open func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool { true }
    /// subclasses draw here, as on iOS: the context's units are this renderer's coordinates (map points from the
    /// overlay's corner, point(for:)), scaled by zoomScale (view points per map point) to the screen
    open func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {}
    open func setNeedsDisplay() { _onChange?() }
    open func setNeedsDisplay(_ mapRect: MKMapRect) { _onChange?() }
    open func setNeedsDisplay(_ mapRect: MKMapRect, zoomScale: MKZoomScale) { _onChange?() }
    var _onChange: (() -> Void)?
    /// isim: draws into the map's overlay layer, where `toView` maps map points to view points (an offset and a scale
    /// of 1/scale). adapted: iOS draws in tiles, each its own draw(_:zoomScale:in:) call; isim makes one call for the
    /// visible part of the overlay
    func _draw(toView: (MKMapPoint) -> CGPoint, scale: CGFloat, visible: MKMapRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let box = overlay.boundingMapRect
        let rect = box.isNull || box.width.isInfinite ? visible : visible.intersection(box.insetBy(dx: -Double(scale) * 50, dy: -Double(scale) * 50))
        let zoom = MKZoomScale(1 / scale)
        guard !rect.isNull, rect.width > 0 || rect.height > 0, canDraw(rect, zoomScale: zoom) else { return }
        let o = toView(box.isNull ? MKMapPoint(x: 0, y: 0) : box.origin)
        ctx.saveGState()
        ctx.translateBy(x: o.x, y: o.y)
        ctx.scaleBy(x: zoom, y: zoom)
        ctx.setAlpha(alpha)
        draw(rect, zoomScale: zoom, in: ctx)
        ctx.restoreGState()
    }
}

/// adapted from iOS: draw(_:zoomScale:in:) makes the path once (createPath), then fills it (applyFillProperties,
/// fillPath) and strokes it (applyStrokeProperties, strokePath). Line widths and dash lengths are in view points.
@objc(MKOverlayPathRenderer) open class MKOverlayPathRenderer: MKOverlayRenderer {
    open var fillColor: UIColor? { didSet { setNeedsDisplay() } }
    open var strokeColor: UIColor? { didSet { setNeedsDisplay() } }
    open var lineWidth: CGFloat = 0 { didSet { setNeedsDisplay() } }
    open var lineJoin: CGLineJoin = .round
    open var lineCap: CGLineCap = .round
    open var miterLimit: CGFloat = 10
    open var lineDashPhase: CGFloat = 0
    open var lineDashPattern: [NSNumber]?
    open var shouldRasterize = false
    open var path: CGPath!
    open func createPath() {}
    open func invalidatePath() { path = nil; setNeedsDisplay() }
    open func applyStrokeProperties(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        let s = 1 / max(zoomScale, 1e-12)
        context.setStrokeColor((strokeColor ?? .clear).cgColor)
        context.setLineWidth(lineWidth * s)
        context.setLineJoin(lineJoin)
        context.setLineCap(lineCap)
        context.setMiterLimit(miterLimit)
        if let d = lineDashPattern, !d.isEmpty {
            context.setLineDash(phase: lineDashPhase * s, lengths: d.map { CGFloat($0.doubleValue) * s })
        }
    }
    open func applyFillProperties(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        context.setFillColor((fillColor ?? .clear).cgColor)
    }
    open func strokePath(_ path: CGPath, in context: CGContext) {
        context.addPath(path)
        context.strokePath()
    }
    open func fillPath(_ path: CGPath, in context: CGContext) {
        context.addPath(path)
        context.fillPath(using: .evenOdd)   /* interior polygons are holes */
    }
    open override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if path == nil { createPath() }
        guard let p = path else { return }
        if fillColor != nil && _fills {
            context.saveGState(); applyFillProperties(to: context, atZoomScale: zoomScale); fillPath(p, in: context); context.restoreGState()
        }
        if strokeColor != nil, lineWidth > 0 {
            context.saveGState(); applyStrokeProperties(to: context, atZoomScale: zoomScale); strokePath(_strokedPath(p), in: context); context.restoreGState()
        }
    }
    var _fills: Bool { true }
    /// the part of the path stroked (strokeStart / strokeEnd of polylines and circles)
    func _strokedPath(_ p: CGPath) -> CGPath { p }
    /// a polyline's points in renderer coordinates, trimmed to the fractions [start, end] of its length
    func _line(_ pts: [MKMapPoint], from start: CGFloat = 0, to end: CGFloat = 1) -> [CGPoint] {
        let q = pts.map { point(for: $0) }
        guard q.count > 1, start > 0 || end < 1 else { return q }
        var lens: [CGFloat] = [0]
        for i in 1..<q.count { lens.append(lens[i - 1] + hypot(q[i].x - q[i - 1].x, q[i].y - q[i - 1].y)) }
        let total = lens.last!, a = max(0, min(1, start)) * total, b = max(0, min(1, end)) * total
        guard b > a else { return [] }
        func at(_ d: CGFloat) -> CGPoint {
            let i = max(1, lens.firstIndex { $0 >= d } ?? q.count - 1)
            let seg = lens[i] - lens[i - 1], t = seg > 0 ? (d - lens[i - 1]) / seg : 0
            return CGPoint(x: q[i - 1].x + (q[i].x - q[i - 1].x) * t, y: q[i - 1].y + (q[i].y - q[i - 1].y) * t)
        }
        var out = [at(a)]
        for i in 0..<q.count where lens[i] > a && lens[i] < b { out.append(q[i]) }
        out.append(at(b))
        return out
    }
    func _addRing(_ pts: [MKMapPoint], to p: CGMutablePath) {
        guard pts.count > 2 else { return }
        p.addLines(between: pts.map { point(for: $0) }); p.closeSubpath()
    }
}

@objc(MKPolylineRenderer) open class MKPolylineRenderer: MKOverlayPathRenderer {
    public init(polyline: MKPolyline) { super.init(overlay: polyline) }
    public override init(overlay: MKOverlay) { super.init(overlay: overlay) }
    open var polyline: MKPolyline { overlay as! MKPolyline }
    open var strokeStart: CGFloat = 0 { didSet { setNeedsDisplay() } }
    open var strokeEnd: CGFloat = 1 { didSet { setNeedsDisplay() } }
    open override func createPath() {
        let p = CGMutablePath()
        let pts = _line(polyline._points)
        if pts.count > 1 { p.addLines(between: pts) }
        path = p
    }
    override func _strokedPath(_ p: CGPath) -> CGPath {
        guard strokeStart > 0 || strokeEnd < 1 else { return p }
        let t = CGMutablePath(), pts = _line(polyline._points, from: strokeStart, to: strokeEnd)
        if pts.count > 1 { t.addLines(between: pts) }
        return t
    }
    override var _fills: Bool { false }   /* a line has no inside */
}
/// adapted: the line is stroked segment by segment, each in the colour at its middle (colours blend between locations)
open class MKGradientPolylineRenderer: MKPolylineRenderer {
    open private(set) var colors: [UIColor] = []
    open private(set) var locations: [CGFloat] = []
    open func setColors(_ colors: [UIColor], locations: [CGFloat]) {
        self.colors = colors
        self.locations = locations.count == colors.count ? locations : colors.indices.map { colors.count > 1 ? CGFloat($0) / CGFloat(colors.count - 1) : 0 }
        setNeedsDisplay()
    }
    func _color(at t: CGFloat) -> UIColor {
        guard let first = colors.first else { return strokeColor ?? .clear }
        guard t > locations[0] else { return first }
        for i in 1..<colors.count where t <= locations[i] {
            let u = (t - locations[i - 1]) / max(1e-9, locations[i] - locations[i - 1])
            var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0, r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            colors[i - 1].getRed(&r0, green: &g0, blue: &b0, alpha: &a0); colors[i].getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            return UIColor(red: r0 + (r1 - r0) * u, green: g0 + (g1 - g0) * u, blue: b0 + (b1 - b0) * u, alpha: a0 + (a1 - a0) * u)
        }
        return colors.last!
    }
    open override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard !colors.isEmpty, lineWidth > 0 else { super.draw(mapRect, zoomScale: zoomScale, in: context); return }
        let all = _line(polyline._points), pts = _line(polyline._points, from: strokeStart, to: strokeEnd)
        guard pts.count > 1 else { return }
        var total: CGFloat = 0
        for i in 1..<all.count { total += hypot(all[i].x - all[i - 1].x, all[i].y - all[i - 1].y) }
        let start = max(0, min(1, strokeStart)) * total
        var run: CGFloat = 0
        context.saveGState()
        applyStrokeProperties(to: context, atZoomScale: zoomScale)
        context.setLineCap(.butt)   /* pieces meet edge to edge (adapted: no round caps at the ends) */
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i], len = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, min(256, Int((len / max(total, 1e-9) * 128).rounded(.up))))   /* long segments in short pieces */
            for k in 0..<n {
                let t0 = CGFloat(k) / CGFloat(n), t1 = CGFloat(k + 1) / CGFloat(n)
                context.setStrokeColor(_color(at: total > 0 ? (start + run + len * (t0 + t1) / 2) / total : 0).cgColor)
                context.move(to: CGPoint(x: a.x + (b.x - a.x) * t0, y: a.y + (b.y - a.y) * t0))
                context.addLine(to: CGPoint(x: a.x + (b.x - a.x) * t1, y: a.y + (b.y - a.y) * t1))
                context.strokePath()
            }
            run += len
        }
        context.restoreGState()
    }
}

@objc(MKPolygonRenderer) open class MKPolygonRenderer: MKOverlayPathRenderer {
    public init(polygon: MKPolygon) { super.init(overlay: polygon) }
    public override init(overlay: MKOverlay) { super.init(overlay: overlay) }
    open var polygon: MKPolygon { overlay as! MKPolygon }
    open var strokeStart: CGFloat = 0
    open var strokeEnd: CGFloat = 1
    open override func createPath() {
        let p = CGMutablePath()
        _addRing(polygon._points, to: p)
        for hole in polygon.interiorPolygons ?? [] { _addRing(hole._points, to: p) }   /* cut out by the even-odd fill */
        path = p
    }
}

@objc(MKCircleRenderer) open class MKCircleRenderer: MKOverlayPathRenderer {
    public init(circle: MKCircle) { super.init(overlay: circle) }
    public override init(overlay: MKOverlay) { super.init(overlay: overlay) }
    open var circle: MKCircle { overlay as! MKCircle }
    open var strokeStart: CGFloat = 0 { didSet { setNeedsDisplay() } }
    open var strokeEnd: CGFloat = 1 { didSet { setNeedsDisplay() } }
    var _circleGeometry: (CGPoint, CGFloat) {
        (point(for: MKMapPoint(circle.coordinate)), CGFloat(circle.radius * MKMapPointsPerMeterAtLatitude(circle.coordinate.latitude)))
    }
    open override func createPath() {
        let (c, r) = _circleGeometry
        path = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
    }
    override func _strokedPath(_ p: CGPath) -> CGPath {
        guard strokeStart > 0 || strokeEnd < 1 else { return p }
        // from the top, clockwise (as iOS draws the circle)
        let (c, r) = _circleGeometry, t = CGMutablePath()
        let a = max(0, min(1, strokeStart)), b = max(a, min(1, strokeEnd))
        t.addArc(center: c, radius: r, startAngle: -.pi / 2 + a * 2 * .pi, endAngle: -.pi / 2 + b * 2 * .pi, clockwise: false)
        return t
    }
}

open class MKMultiPolylineRenderer: MKOverlayPathRenderer {
    public init(multiPolyline: MKMultiPolyline) { super.init(overlay: multiPolyline) }
    open var multiPolyline: MKMultiPolyline { overlay as! MKMultiPolyline }
    open override func createPath() {
        let p = CGMutablePath()
        for l in multiPolyline.polylines where l._points.count > 1 { p.addLines(between: _line(l._points)) }
        path = p
    }
    override var _fills: Bool { false }
}
open class MKMultiPolygonRenderer: MKOverlayPathRenderer {
    public init(multiPolygon: MKMultiPolygon) { super.init(overlay: multiPolygon) }
    open var multiPolygon: MKMultiPolygon { overlay as! MKMultiPolygon }
    open override func createPath() {
        let p = CGMutablePath()
        for g in multiPolygon.polygons {
            _addRing(g._points, to: p)
            for hole in g.interiorPolygons ?? [] { _addRing(hole._points, to: p) }
        }
        path = p
    }
}

open class MKTileOverlayRenderer: MKOverlayRenderer {
    public init(tileOverlay overlay: MKTileOverlay) { super.init(overlay: overlay) }
    var cache: [String: UIImage] = [:]
    var loading: Set<String> = []
    open func reloadData() { cache.removeAll(); setNeedsDisplay() }
    override func _draw(toView: (MKMapPoint) -> CGPoint, scale: CGFloat, visible: MKMapRect) {
        guard let t = overlay as? MKTileOverlay else { return }
        _MKTiles.draw(visible: visible, scale: scale, toView: toView, minZ: t.minimumZ, maxZ: t.maximumZ, alpha: alpha) { path in
            let key = "\(path.z)/\(path.x)/\(path.y)"
            if let img = cache[key] { return img }
            if !loading.contains(key) {
                loading.insert(key)
                t.loadTile(at: path) { [weak self] d, _ in
                    guard let self else { return }
                    if let d, let img = UIImage(data: d) { self.cache[key] = img; self.setNeedsDisplay() }
                }
            }
            return cache[key]
        }
    }
}

/// shared slippy-map tile drawing (tile overlays and the cached basemap)
enum _MKTiles {
    static func draw(visible: MKMapRect, scale: CGFloat, toView: (MKMapPoint) -> CGPoint, minZ: Int, maxZ: Int, alpha: CGFloat,
                     tile: (MKTileOverlayPath) -> UIImage?) {
        // the zoom where one 256-pixel tile covers 256 view points (or fewer)
        let ptsPerTile = Double(scale) * 256
        var z = Int((log2(_MKWorld / ptsPerTile)).rounded())
        z = max(minZ, min(maxZ, z))
        let n = 1 << z, tileMap = _MKWorld / Double(n)
        let x0 = max(0, Int(visible.minX / tileMap)), x1 = min(n - 1, Int(visible.maxX / tileMap))
        let y0 = max(0, Int(visible.minY / tileMap)), y1 = min(n - 1, Int(visible.maxY / tileMap))
        guard x1 >= x0, y1 >= y0, (x1 - x0 + 1) * (y1 - y0 + 1) <= 400 else { return }
        for y in y0...y1 { for x in x0...x1 {
            guard let img = tile(MKTileOverlayPath(x: x, y: y, z: z, contentScaleFactor: UIScreen.main.scale)) else { continue }
            let a = toView(MKMapPoint(x: Double(x) * tileMap, y: Double(y) * tileMap)), b = toView(MKMapPoint(x: Double(x + 1) * tileMap, y: Double(y + 1) * tileMap))
            img.draw(in: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y))
        } }
    }
}

func _alphaOf(_ c: UIColor) -> CGFloat { var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1; c.getRed(&r, green: &g, blue: &b, alpha: &a); return a }
