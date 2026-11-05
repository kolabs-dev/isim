// isim SwiftUI: more of Shape, ShapeStyle, Font, Text, Image and Spring (issue #868, part 2): the shape and style
// static members, the semantic shape styles (separator, placeholder, link, fill, selection, window background), style
// modifiers, Font's Bool forms and small caps, Image's cap-inset resizing and Spring's value / velocity / force maths.
import UIKit

// MARK: - shape statics

extension Shape where Self == Circle { public static var circle: Circle { Circle() } }
extension Shape where Self == Capsule {
    public static var capsule: Capsule { Capsule() }
    public static func capsule(style: RoundedCornerStyle) -> Capsule { Capsule(style: style) }
}
extension Shape where Self == Ellipse { public static var ellipse: Ellipse { Ellipse() } }
extension Shape where Self == Rectangle { public static var rect: Rectangle { Rectangle() } }
extension Shape where Self == ContainerRelativeShape { public static var containerRelative: ContainerRelativeShape { ContainerRelativeShape() } }
extension Shape where Self == RoundedRectangle {
    public static func rect(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) -> RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: style) }
    public static func rect(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) -> RoundedRectangle { RoundedRectangle(cornerSize: cornerSize, style: style) }
}
extension Shape where Self == UnevenRoundedRectangle {
    public static func rect(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: cornerRadii, style: style)
    }
    public static func rect(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0,
                            topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: topLeadingRadius, bottomLeadingRadius: bottomLeadingRadius,
                               bottomTrailingRadius: bottomTrailingRadius, topTrailingRadius: topTrailingRadius, style: style)
    }
}

extension Shape {
    /// the shape sized to `size`, placed at `anchor` of the frame it is drawn in (isim keeps the top-leading placement)
    public func size(_ size: CGSize, anchor: UnitPoint) -> some Shape { self.size(width: size.width, height: size.height) }
    public func size(width: CGFloat, height: CGFloat, anchor: UnitPoint) -> some Shape { self.size(width: width, height: height) }
}

// MARK: - shape styles

/// A style that falls back to a UIKit colour (the semantic styles below)
protocol _UIKitShapeStyle: ShapeStyle, _ColorFallback { var _ui: UIColor { get } }
extension _UIKitShapeStyle { func _fallbackColor(_ env: EnvironmentValues) -> Color { Color(uiColor: _ui) } }

/// The colour of separators (UIColor.separator).
public struct SeparatorShapeStyle: _UIKitShapeStyle, Sendable { public init() {}; var _ui: UIColor { .separator } }
/// The colour of placeholder text (UIColor.placeholderText).
public struct PlaceholderTextShapeStyle: _UIKitShapeStyle, Sendable { public init() {}; var _ui: UIColor { .placeholderText } }
/// The colour of links (UIColor.link).
public struct LinkShapeStyle: _UIKitShapeStyle, Sendable { public init() {}; var _ui: UIColor { .link } }
/// The fill colour of shapes (UIColor.systemFill).
public struct FillShapeStyle: _UIKitShapeStyle, Sendable { public init() {}; var _ui: UIColor { .systemFill } }
/// The colour of selected content (the tint colour on iOS).
public struct SelectionShapeStyle: _UIKitShapeStyle, Sendable { public init() {}; var _ui: UIColor { .tintColor } }
/// The window's background colour (UIColor.systemBackground).
public struct WindowBackgroundShapeStyle: _UIKitShapeStyle, Sendable { public init() {}; var _ui: UIColor { .systemBackground } }

extension ShapeStyle where Self == SeparatorShapeStyle { public static var separator: SeparatorShapeStyle { SeparatorShapeStyle() } }
extension ShapeStyle where Self == PlaceholderTextShapeStyle { public static var placeholder: PlaceholderTextShapeStyle { PlaceholderTextShapeStyle() } }
extension ShapeStyle where Self == LinkShapeStyle { public static var link: LinkShapeStyle { LinkShapeStyle() } }
extension ShapeStyle where Self == FillShapeStyle { public static var fill: FillShapeStyle { FillShapeStyle() } }
extension ShapeStyle where Self == SelectionShapeStyle { public static var selection: SelectionShapeStyle { SelectionShapeStyle() } }
extension ShapeStyle where Self == WindowBackgroundShapeStyle { public static var windowBackground: WindowBackgroundShapeStyle { WindowBackgroundShapeStyle() } }
extension ShapeStyle where Self == Color {
    public static var brown: Color { Color.brown }
    public static var cyan: Color { Color.cyan }
    public static var indigo: Color { Color.indigo }
    public static var mint: Color { Color.mint }
    public static var teal: Color { Color.teal }
}

/// A style drawn at an opacity (ShapeStyle.opacity(_:)).
struct _OpacityShapeStyle: ShapeStyle, _ColorFallback {
    let base: any ShapeStyle, opacity: Double
    func _fallbackColor(_ env: EnvironmentValues) -> Color { MainActor.assumeIsolated { _color(of: base, env).opacity(opacity) } }
}
extension ShapeStyle {
    public func opacity(_ opacity: Double) -> some ShapeStyle { _OpacityShapeStyle(base: self, opacity: opacity) }
    /// isim draws shape styles with the normal blend mode
    public func blendMode(_ mode: BlendMode) -> some ShapeStyle { self }
    /// isim draws shape styles without their shadow
    public func shadow(_ style: ShadowStyle) -> some ShapeStyle { self }
    /// the style mapped into a rectangle (gradients there); the colour styles are unchanged
    public func `in`(_ rect: CGRect) -> some ShapeStyle { self }
    public func materialActiveAppearance(_ appearance: MaterialActiveAppearance) -> some ShapeStyle { self }
}
extension ShapeStyle where Self == AnyShapeStyle {
    public static func opacity(_ opacity: Double) -> some ShapeStyle { _OpacityShapeStyle(base: ForegroundStyle(), opacity: opacity) }
    public static func blendMode(_ mode: BlendMode) -> some ShapeStyle { ForegroundStyle() }
    public static func shadow(_ style: ShadowStyle) -> some ShapeStyle { ForegroundStyle() }
}

// MARK: - Font

extension Font {
    /// the default font (body)
    public static var `default`: Font { .body }
    public static func system(_ style: TextStyle, design: Design) -> Font { system(style, design: Optional(design), weight: nil) }
    public func bold(_ isActive: Bool) -> Font { isActive ? bold() : self }
    public func italic(_ isActive: Bool) -> Font { isActive ? italic() : self }
    public func monospaced(_ isActive: Bool) -> Font { isActive ? monospaced() : self }
    /// the same font at another size
    public func pointSize(_ size: CGFloat) -> Font { var f = self; f.size = size; f.textStyle = nil; return f }
    /// the same font scaled
    public func scaled(by factor: CGFloat) -> Font { var f = self; f.size = f.size * factor; return f }
    /// small capitals (isim draws the font's regular capitals)
    public func smallCaps() -> Font { self }
    public func smallCaps(_ isActive: Bool) -> Font { self }
    public func lowercaseSmallCaps() -> Font { self }
    public func lowercaseSmallCaps(_ isActive: Bool) -> Font { self }
    public func uppercaseSmallCaps() -> Font { self }
    public func uppercaseSmallCaps(_ isActive: Bool) -> Font { self }
}

// MARK: - Text

extension Text {
    @_disfavoredOverload public func bold() -> Text { bold(true) }
    @_disfavoredOverload public func italic() -> Text { italic(true) }
    // Text keeps no accessibility attributes of its own: these are stubs (the View modifiers set them on the view)
    public func speechAdjustedPitch(_ value: Double) -> Text { self }
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> Text { self }
    public func speechAnnouncementsQueued(_ value: Bool = true) -> Text { self }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> Text { self }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> Text { self }
}
extension Text.LineStyle {
    /// the line style of an NSUnderlineStyle (nil for none)
    public init?(nsUnderlineStyle: NSUnderlineStyle) {
        guard nsUnderlineStyle.rawValue != 0 else { return nil }
        let pattern: Pattern = nsUnderlineStyle.contains(.patternDot) ? .dot : nsUnderlineStyle.contains(.patternDash) ? .dash
            : nsUnderlineStyle.contains(.patternDashDot) ? .dashDot : nsUnderlineStyle.contains(.patternDashDotDot) ? .dashDotDot : .solid
        self.init(pattern: pattern, color: nil)
    }
}

// MARK: - Image

extension Image {
    public enum ResizingMode: Hashable, Sendable { case tile, stretch }
    /// resizable with cap insets (isim stretches the whole image; tiling draws it stretched)
    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Image { resizable() }
    public func symbolColorRenderingMode(_ mode: SymbolColorRenderingMode?) -> Image { self }
    public func symbolVariableValueMode(_ mode: SymbolVariableValueMode?) -> Image { self }
}

// MARK: - Spring

extension Spring {
    public static func smooth(duration: TimeInterval = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: extraBounce) }
    public static func snappy(duration: TimeInterval = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: 0.15 + extraBounce) }
    public static func bouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0) -> Spring { Spring(duration: duration, bounce: 0.3 + extraBounce) }
    /// the spring that settles (within `epsilon`) in `settlingDuration`
    public init(settlingDuration: TimeInterval, dampingRatio: Double, epsilon: Double = 0.001) {
        // settling time of a damped spring ~ -ln(epsilon) / (zeta * omega): solve for the response
        let z = max(0.01, dampingRatio), w = -log(max(1e-9, epsilon)) / (min(z, 1) * max(0.001, settlingDuration))
        self.init(response: 2 * .pi / w, dampingRatio: dampingRatio)
    }
    public func value<V: VectorArithmetic>(fromValue: V, toValue: V, initialVelocity: V, time: TimeInterval) -> V {
        fromValue + value(target: toValue - fromValue, initialVelocity: initialVelocity, time: time)
    }
    public func velocity<V: VectorArithmetic>(fromValue: V, toValue: V, initialVelocity: V, time: TimeInterval) -> V {
        velocity(target: toValue - fromValue, initialVelocity: initialVelocity, time: time)
    }
    /// the spring's force on a value at `position` moving at `velocity`, toward `target`: k (target - x) - c v
    public func force<V: VectorArithmetic>(target: V, position: V, velocity: V) -> V {
        var pull = target - position; pull.scale(by: stiffness)
        var drag = velocity; drag.scale(by: damping)
        return pull - drag
    }
    public func force<V: VectorArithmetic>(fromValue: V, toValue: V, position: V, velocity: V) -> V {
        force(target: toValue - fromValue, position: position - fromValue, velocity: velocity)
    }
    public func settlingDuration<V: VectorArithmetic>(target: V, initialVelocity: V, epsilon: Double) -> TimeInterval {
        let w = 2 * .pi / response, z = max(0.01, dampingRatio)
        let scale = max(1e-9, target.magnitudeSquared.squareRoot() + initialVelocity.magnitudeSquared.squareRoot() / w)
        return -log(max(1e-12, epsilon / scale)) / (min(z, 1) * w)
    }
    public func settlingDuration<V: VectorArithmetic>(fromValue: V, toValue: V, initialVelocity: V, epsilon: Double) -> TimeInterval {
        settlingDuration(target: toValue - fromValue, initialVelocity: initialVelocity, epsilon: epsilon)
    }
    /// one step of the spring's motion (semi-implicit Euler)
    public func update<V: VectorArithmetic>(value: inout V, velocity: inout V, target: V, deltaTime: TimeInterval) {
        var a = force(target: target, position: value, velocity: velocity)   // mass 1
        a.scale(by: deltaTime)
        velocity += a
        var dv = velocity; dv.scale(by: deltaTime)
        value += dv
    }
}

/// A shadow a shape style draws with (iOS 16): drop shadows outside, inner shadows inside.
public struct ShadowStyle: Equatable, Sendable {
    let inner: Bool, color: Color, radius: CGFloat, x: CGFloat, y: CGFloat
    public static func drop(color: Color = Color.black.opacity(0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle {
        ShadowStyle(inner: false, color: color, radius: radius, x: x, y: y)
    }
    public static func inner(color: Color = Color.black.opacity(0.55), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle {
        ShadowStyle(inner: true, color: color, radius: radius, x: x, y: y)
    }
}
