// isim SwiftUI (iOS 26): Slider tick marks — `SliderTick`, `SliderTickBuilder`, `SliderTickContentForEach`, the
// `ticks:` / `tick:` initializers, ticks shown for a stepped slider — and `neutralValue` / `enabledBounds`.
// Adapted: drawn by UIKit's slider track configuration (UISlider.TrackConfiguration: dots on the track, a fill from
// the neutral value, the track outside the enabled range dimmed); tick labels are kept, not drawn (like UIKit's titles).
import UIKit

/// A tick's value (as a Double) and label.
struct _SliderTickSpec { let value: Double; let label: AnyView? }

public protocol SliderTickContent<ValueType> {
    associatedtype ValueType: BinaryFloatingPoint
    var _ticks: [(ValueType, AnyView?)] { get }
}
/// A tick mark at a value, with an optional label.
@available(iOS 26.0, *)
public struct SliderTick<V: BinaryFloatingPoint>: SliderTickContent {
    public typealias ValueType = V
    let value: V, label: AnyView?
    public init(_ value: V) { self.value = value; label = nil }
    public init<L: View>(_ value: V, @ViewBuilder label: () -> L) { self.value = value; self.label = AnyView(label()) }
    public var _ticks: [(V, AnyView?)] { [(value, label)] }
}
/// Ticks built from a collection.
@available(iOS 26.0, *)
public struct SliderTickContentForEach<Data: RandomAccessCollection, ID: Hashable, Content: SliderTickContent>: SliderTickContent {
    public typealias ValueType = Content.ValueType
    let data: Data, content: (Data.Element) -> Content
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, content: @escaping (Data.Element) -> Content) {
        self.data = data; self.content = content
    }
    public init(_ data: Data, content: @escaping (Data.Element) -> Content) where Data.Element == ID {
        self.data = data; self.content = content
    }
    public var _ticks: [(ValueType, AnyView?)] { data.flatMap { content($0)._ticks } }
}
/// Several ticks (what the builder produces).
public struct _SliderTickGroup<V: BinaryFloatingPoint>: SliderTickContent {
    public typealias ValueType = V
    public let _ticks: [(V, AnyView?)]
}
@resultBuilder
public struct SliderTickBuilder<V: BinaryFloatingPoint> {
    public static func buildExpression<C: SliderTickContent>(_ c: C) -> _SliderTickGroup<V> where C.ValueType == V { _SliderTickGroup(_ticks: c._ticks) }
    public static func buildBlock(_ parts: _SliderTickGroup<V>...) -> _SliderTickGroup<V> { _SliderTickGroup(_ticks: parts.flatMap(\._ticks)) }
    public static func buildOptional(_ c: _SliderTickGroup<V>?) -> _SliderTickGroup<V> { c ?? _SliderTickGroup(_ticks: []) }
    public static func buildEither(first c: _SliderTickGroup<V>) -> _SliderTickGroup<V> { c }
    public static func buildEither(second c: _SliderTickGroup<V>) -> _SliderTickGroup<V> { c }
    public static func buildArray(_ c: [_SliderTickGroup<V>]) -> _SliderTickGroup<V> { _SliderTickGroup(_ticks: c.flatMap(\._ticks)) }
}

@available(iOS 26.0, *)
extension Slider {
    init<V: BinaryFloatingPoint>(_ value: Binding<V>, _ bounds: ClosedRange<V>, step: Double?, neutral: V?, enabled: ClosedRange<V>?,
                                 label: Label?, minLabel: ValueLabel?, maxLabel: ValueLabel?, ticks: [(V, AnyView?)]?, onEditingChanged: @escaping (Bool) -> Void) {
        self.value = Slider._double(value); self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound); self.step = step
        self.onEditingChanged = onEditingChanged; self.label = label; self.minLabel = minLabel; self.maxLabel = maxLabel
        self.ticks = ticks?.map { _SliderTickSpec(value: Double($0.0), label: $0.1) }
        self.neutral = neutral.map(Double.init); self.enabledBounds = enabled.map { Double($0.lowerBound)...Double($0.upperBound) }
    }
    /// Custom ticks, a neutral value and an enabled range, with value labels.
    public init<V: BinaryFloatingPoint, T: SliderTickContent>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, neutralValue: V? = nil,
                                                              enabledBounds: ClosedRange<V>? = nil, @ViewBuilder label: () -> Label,
                                                              @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel,
                                                              @SliderTickBuilder<V> ticks: () -> T, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint, T.ValueType == V {
        self.init(value, bounds, step: nil, neutral: neutralValue, enabled: enabledBounds, label: label(), minLabel: minimumValueLabel(),
                  maxLabel: maximumValueLabel(), ticks: ticks()._ticks, onEditingChanged: onEditingChanged)
    }
    /// A stepped slider with custom ticks and value labels.
    public init<V: BinaryFloatingPoint, T: SliderTickContent>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride, neutralValue: V? = nil,
                                                              enabledBounds: ClosedRange<V>? = nil, @ViewBuilder label: () -> Label,
                                                              @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel,
                                                              @SliderTickBuilder<V> ticks: () -> T, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint, T.ValueType == V {
        self.init(value, bounds, step: Double(step), neutral: neutralValue, enabled: enabledBounds, label: label(), minLabel: minimumValueLabel(),
                  maxLabel: maximumValueLabel(), ticks: ticks()._ticks, onEditingChanged: onEditingChanged)
    }
}
@available(iOS 26.0, *)
extension Slider where ValueLabel == EmptyView {
    /// Custom ticks (and a neutral value, an enabled range).
    public init<V: BinaryFloatingPoint, T: SliderTickContent>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, neutralValue: V? = nil,
                                                              enabledBounds: ClosedRange<V>? = nil, @ViewBuilder label: () -> Label,
                                                              @SliderTickBuilder<V> ticks: () -> T, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint, T.ValueType == V {
        self.init(value, bounds, step: nil, neutral: neutralValue, enabled: enabledBounds, label: label(), minLabel: nil, maxLabel: nil,
                  ticks: ticks()._ticks, onEditingChanged: onEditingChanged)
    }
    /// A stepped slider with custom ticks.
    public init<V: BinaryFloatingPoint, T: SliderTickContent>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride, neutralValue: V? = nil,
                                                              enabledBounds: ClosedRange<V>? = nil, @ViewBuilder label: () -> Label,
                                                              @SliderTickBuilder<V> ticks: () -> T, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint, T.ValueType == V {
        self.init(value, bounds, step: Double(step), neutral: neutralValue, enabled: enabledBounds, label: label(), minLabel: nil, maxLabel: nil,
                  ticks: ticks()._ticks, onEditingChanged: onEditingChanged)
    }
    /// A stepped slider whose ticks come from a closure called with each step's value (nil: no tick there).
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, neutralValue: V? = nil,
                                        enabledBounds: ClosedRange<V>? = nil, @ViewBuilder label: () -> Label,
                                        tick: (V) -> SliderTick<V>?, onEditingChanged: @escaping (Bool) -> Void = { _ in })
    where V.Stride: BinaryFloatingPoint {
        var ticks: [(V, AnyView?)] = []
        var v = bounds.lowerBound
        while v <= bounds.upperBound, ticks.count < 1000 { if let t = tick(v) { ticks += t._ticks }; v = v.advanced(by: step) }
        self.init(value, bounds, step: Double(step), neutral: neutralValue, enabled: enabledBounds, label: label(), minLabel: nil, maxLabel: nil,
                  ticks: ticks, onEditingChanged: onEditingChanged)
    }
}
@available(iOS 26.0, *)
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    /// A slider whose fill starts from `neutralValue` (and that stays inside `enabledBounds`).
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, neutralValue: V, enabledBounds: ClosedRange<V>? = nil,
                                        onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {
        self.init(value, bounds, step: nil, neutral: neutralValue, enabled: enabledBounds, label: nil, minLabel: nil, maxLabel: nil,
                  ticks: nil, onEditingChanged: onEditingChanged)
    }
}

/// The UIKit track configuration of a slider: its ticks (a stepped slider's steps when it has no ticks of its own,
/// up to 20, iOS 26 style), neutral value and enabled range, as fractions of the track; nil when it has none.
@available(iOS 26.0, *)
@MainActor func _sliderTrack(_ n: _SliderNode) -> UISlider.TrackConfiguration? {
    let lo = n.bounds.lowerBound, span = max(1e-12, n.bounds.upperBound - lo)
    func frac(_ v: Double) -> Float { Float(min(1, max(0, (v - lo) / span))) }
    var ticks = n.ticks?.map { UISlider.TrackConfiguration.Tick(position: frac($0.value)) }
    var tickValuesOnly = false
    if ticks == nil, let st = n.step, st > 0 {
        let count = Int((span / st).rounded(.down)) + 1
        if count >= 2 && count <= 21 { ticks = (0..<count).map { .init(position: frac(lo + Double($0) * st)) }; tickValuesOnly = true }
    }
    guard ticks != nil || n.neutral != nil || n.enabledBounds != nil else { return nil }
    let enabled = n.enabledBounds.map { frac($0.lowerBound)...max(frac($0.lowerBound), frac($0.upperBound)) } ?? 0...1
    return UISlider.TrackConfiguration(allowsTickValuesOnly: tickValuesOnly, neutralValue: n.neutral.map(frac) ?? 0, enabledRange: enabled, ticks: ticks ?? [])
}
