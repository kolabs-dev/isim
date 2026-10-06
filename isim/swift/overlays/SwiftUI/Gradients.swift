// isim SwiftUI: gradients (linear, radial, angular/conic, elliptical, Color.gradient) and image paint.
// Each is a ShapeStyle (fill, stroke, foregroundStyle, background) and a View (fills its frame).
// Geometry is relative to the frame of the shape or view being painted, like SwiftUI. Stop colors and
// gradient geometry animate. Text painted with a gradient uses its first color.
import UIKit

public struct Gradient: Hashable, @unchecked Sendable {
    public struct Stop: Hashable, @unchecked Sendable {
        public var color: Color
        public var location: CGFloat
        public init(color: Color, location: CGFloat) { self.color = color; self.location = location }
    }
    public var stops: [Stop]
    public init(stops: [Stop]) { self.stops = stops }
    public init(colors: [Color]) {
        stops = colors.enumerated().map { Stop(color: $0.element, location: colors.count > 1 ? CGFloat($0.offset) / CGFloat(colors.count - 1) : 0) }
    }
    @MainActor var _stops: [_Stop] {
        let sorted = stops.enumerated().sorted { ($0.element.location, $0.offset) < ($1.element.location, $1.offset) }.map(\.element)
        return sorted.map { _Stop(color: $0.color.uiColor, location: Double($0.location)) }
    }
    @MainActor func _vector() -> [Double] { stops.flatMap { _rgbaOf($0.color.uiColor) + [Double($0.location)] } }
    @MainActor func _with(_ v: ArraySlice<Double>) -> Gradient? {
        guard v.count == stops.count * 5 else { return nil }
        let a = Array(v)
        return Gradient(stops: (0..<stops.count).map { i in
            Stop(color: Color(red: a[i * 5], green: a[i * 5 + 1], blue: a[i * 5 + 2], opacity: a[i * 5 + 3]), location: a[i * 5 + 4])
        })
    }
    /// SwiftUI 16+: interpolation color space (isim interpolates in sRGB).
    public enum ColorSpace: Hashable, Sendable { case device, perceptual }
    public func colorSpace(_ space: ColorSpace) -> AnyGradient { AnyGradient(self) }
}

func _unit(_ u: UnitPoint, _ r: CGRect) -> CGPoint { CGPoint(x: r.minX + u.x * r.width, y: r.minY + u.y * r.height) }

/// A gradient used as a shape style: top to bottom over the shape (also what Color.gradient gives).
public struct AnyGradient: ShapeStyle, Hashable, @unchecked Sendable, _PaintStyle, _ColorFallback, _AnimatableStyle {
    let gradient: Gradient
    public init(_ gradient: Gradient) { self.gradient = gradient }
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint { .linear(gradient._stops, _unit(.top, rect), _unit(.bottom, rect), extend: 1) }
    func _fallbackColor(_ env: EnvironmentValues) -> Color { gradient.stops.first?.color ?? .clear }
    func _vector() -> [Double] { gradient._vector() }
    func _with(_ v: [Double]) -> AnyGradient? { gradient._with(v[...]).map(AnyGradient.init) }
}
extension Gradient: ShapeStyle, _PaintStyle, _ColorFallback {
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint { AnyGradient(self)._paint(in: rect, env) }
    func _fallbackColor(_ env: EnvironmentValues) -> Color { stops.first?.color ?? .clear }
}
extension Color {
    /// A subtle top-to-bottom gradient of the color (a little lighter at the top).
    public var gradient: AnyGradient {
        let base = self
        let top = Color("\(provider.name).gradientTop") {
            let c = _rgbaOf(base.uiColor)
            return UIColor(red: c[0] + (1 - c[0]) * 0.18, green: c[1] + (1 - c[1]) * 0.18, blue: c[2] + (1 - c[2]) * 0.18, alpha: c[3])
        }
        return AnyGradient(Gradient(colors: [top, base]))
    }
}

public struct LinearGradient: ShapeStyle, View, _PaintStyle, _ColorFallback, _AnimatableStyle, @unchecked Sendable {
    var gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint
    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) { self.gradient = gradient; self.startPoint = startPoint; self.endPoint = endPoint }
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) { self.init(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint) }
    public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) { self.init(gradient: Gradient(stops: stops), startPoint: startPoint, endPoint: endPoint) }
    public var body: _ShapeView<Rectangle, LinearGradient> { _ShapeView(shape: Rectangle(), style: self) }
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint { .linear(gradient._stops, _unit(startPoint, rect), _unit(endPoint, rect), extend: 1) }
    func _fallbackColor(_ env: EnvironmentValues) -> Color { gradient.stops.first?.color ?? .clear }
    func _vector() -> [Double] { gradient._vector() + [startPoint.x, startPoint.y, endPoint.x, endPoint.y] }
    func _with(_ v: [Double]) -> LinearGradient? {
        guard v.count >= 4, let g = gradient._with(v.dropLast(4)) else { return nil }
        let n = v.count
        return LinearGradient(gradient: g, startPoint: UnitPoint(x: v[n - 4], y: v[n - 3]), endPoint: UnitPoint(x: v[n - 2], y: v[n - 1]))
    }
}

public struct RadialGradient: ShapeStyle, View, _PaintStyle, _ColorFallback, _AnimatableStyle, @unchecked Sendable {
    var gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat
    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {
        self.gradient = gradient; self.center = center; self.startRadius = startRadius; self.endRadius = endRadius
    }
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) { self.init(gradient: Gradient(colors: colors), center: center, startRadius: startRadius, endRadius: endRadius) }
    public init(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) { self.init(gradient: Gradient(stops: stops), center: center, startRadius: startRadius, endRadius: endRadius) }
    public var body: _ShapeView<Rectangle, RadialGradient> { _ShapeView(shape: Rectangle(), style: self) }
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint { .radial(gradient._stops, _unit(center, rect), startRadius, endRadius, matrix: nil, extend: 1) }
    func _fallbackColor(_ env: EnvironmentValues) -> Color { gradient.stops.first?.color ?? .clear }
    func _vector() -> [Double] { gradient._vector() + [center.x, center.y, startRadius, endRadius] }
    func _with(_ v: [Double]) -> RadialGradient? {
        guard v.count >= 4, let g = gradient._with(v.dropLast(4)) else { return nil }
        let n = v.count
        return RadialGradient(gradient: g, center: UnitPoint(x: v[n - 4], y: v[n - 3]), startRadius: v[n - 2], endRadius: v[n - 1])
    }
}

/// An angular (conic) gradient: angle 0 points to the trailing edge and angles grow clockwise.
public struct AngularGradient: ShapeStyle, View, _PaintStyle, _ColorFallback, _AnimatableStyle, @unchecked Sendable {
    var gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle
    public init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {
        self.gradient = gradient; self.center = center; self.startAngle = startAngle; self.endAngle = endAngle
    }
    public init(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) { self.init(gradient: Gradient(colors: colors), center: center, startAngle: startAngle, endAngle: endAngle) }
    public init(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) { self.init(gradient: Gradient(stops: stops), center: center, startAngle: startAngle, endAngle: endAngle) }
    /// A full turn starting at `angle`.
    public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) { self.init(gradient: gradient, center: center, startAngle: angle, endAngle: angle + .degrees(360)) }
    public init(colors: [Color], center: UnitPoint, angle: Angle = .zero) { self.init(gradient: Gradient(colors: colors), center: center, angle: angle) }
    public init(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) { self.init(gradient: Gradient(stops: stops), center: center, angle: angle) }
    public var body: _ShapeView<Rectangle, AngularGradient> { _ShapeView(shape: Rectangle(), style: self) }
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint {
        var end = endAngle.radians
        if end <= startAngle.radians { end = startAngle.radians + 2 * .pi }
        return .conic(gradient._stops, _unit(center, rect), startAngle.radians, end)
    }
    func _fallbackColor(_ env: EnvironmentValues) -> Color { gradient.stops.first?.color ?? .clear }
    func _vector() -> [Double] { gradient._vector() + [center.x, center.y, startAngle.radians, endAngle.radians] }
    func _with(_ v: [Double]) -> AngularGradient? {
        guard v.count >= 4, let g = gradient._with(v.dropLast(4)) else { return nil }
        let n = v.count
        return AngularGradient(gradient: g, center: UnitPoint(x: v[n - 4], y: v[n - 3]), startAngle: .radians(v[n - 2]), endAngle: .radians(v[n - 1]))
    }
}

/// A radial gradient stretched to the frame: radius fractions are relative to the frame's size (0.5 reaches the edges).
public struct EllipticalGradient: ShapeStyle, View, _PaintStyle, _ColorFallback, _AnimatableStyle, @unchecked Sendable {
    var gradient: Gradient, center: UnitPoint, startRadiusFraction: CGFloat, endRadiusFraction: CGFloat
    public init(gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.gradient = gradient; self.center = center; self.startRadiusFraction = startRadiusFraction; self.endRadiusFraction = endRadiusFraction
    }
    public init(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.init(gradient: Gradient(colors: colors), center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public init(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {
        self.init(gradient: Gradient(stops: stops), center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public var body: _ShapeView<Rectangle, EllipticalGradient> { _ShapeView(shape: Rectangle(), style: self) }
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint {
        let m = CGAffineTransform(a: max(rect.width, 0.001), b: 0, c: 0, d: max(rect.height, 0.001), tx: rect.minX, ty: rect.minY)
        return .radial(gradient._stops, CGPoint(x: center.x, y: center.y), startRadiusFraction, endRadiusFraction, matrix: m, extend: 1)
    }
    func _fallbackColor(_ env: EnvironmentValues) -> Color { gradient.stops.first?.color ?? .clear }
    func _vector() -> [Double] { gradient._vector() + [center.x, center.y, startRadiusFraction, endRadiusFraction] }
    func _with(_ v: [Double]) -> EllipticalGradient? {
        guard v.count >= 4, let g = gradient._with(v.dropLast(4)) else { return nil }
        let n = v.count
        return EllipticalGradient(gradient: g, center: UnitPoint(x: v[n - 4], y: v[n - 3]), startRadiusFraction: v[n - 2], endRadiusFraction: v[n - 1])
    }
}

extension ShapeStyle where Self == LinearGradient {
    public static func linearGradient(_ gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(_ gradient: AnyGradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(gradient: gradient.gradient, startPoint: startPoint, endPoint: endPoint) }
}
extension ShapeStyle where Self == RadialGradient {
    public static func radialGradient(_ gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { RadialGradient(gradient: gradient, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { RadialGradient(stops: stops, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(_ gradient: AnyGradient, center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat) -> RadialGradient { RadialGradient(gradient: gradient.gradient, center: center, startRadius: startRadius, endRadius: endRadius) }
}
extension ShapeStyle where Self == AngularGradient {
    public static func angularGradient(_ gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { AngularGradient(gradient: gradient, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func angularGradient(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func angularGradient(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { AngularGradient(stops: stops, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func conicGradient(_ gradient: Gradient, center: UnitPoint, angle: Angle = .zero) -> AngularGradient { AngularGradient(gradient: gradient, center: center, angle: angle) }
    public static func conicGradient(colors: [Color], center: UnitPoint, angle: Angle = .zero) -> AngularGradient { AngularGradient(colors: colors, center: center, angle: angle) }
    public static func conicGradient(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) -> AngularGradient { AngularGradient(stops: stops, center: center, angle: angle) }
}
extension ShapeStyle where Self == EllipticalGradient {
    public static func ellipticalGradient(_ gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(gradient: gradient, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public static func ellipticalGradient(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(colors: colors, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
    public static func ellipticalGradient(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient {
        EllipticalGradient(stops: stops, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction)
    }
}

// MARK: - ImagePaint

/// Tiles an image (or a unit-coordinate part of it) over the shape.
public struct ImagePaint: ShapeStyle, _PaintStyle, @unchecked Sendable {
    public var image: Image
    public var sourceRect: CGRect
    public var scale: CGFloat
    public init(image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) {
        self.image = image; self.sourceRect = sourceRect; self.scale = scale
    }
    func _paint(in rect: CGRect, _ env: EnvironmentValues) -> _Paint {
        guard let img = _uiImage(image, env) else { return .color(.clear) }
        return .image(img, origin: rect.origin, source: sourceRect, scale: scale)
    }
}
extension ShapeStyle where Self == ImagePaint {
    public static func image(_ image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> ImagePaint {
        ImagePaint(image: image, sourceRect: sourceRect, scale: scale)
    }
}
/// The UIImage an Image shows (symbols at the environment's font size, tinted with the foreground color).
@MainActor func _uiImage(_ image: Image, _ env: EnvironmentValues) -> UIImage? {
    let font = (env.font ?? .body).uiFont
    switch image.source {
    case .system(let n):
        let color = (image.renderingMode == .original ? nil : _styleColor(ForegroundStyle(), env).uiColor)
        let img = UIImage(systemName: n, withConfiguration: UIImage.SymbolConfiguration(font: font))
        return color.flatMap { img?.withTintColor($0) } ?? img
    case .named(let n, _):
        let img = UIImage(named: n)
        if image.renderingMode == .template { return img?.withTintColor(_styleColor(ForegroundStyle(), env).uiColor) }
        return img
    case .ui(let u): return u
    }
}
