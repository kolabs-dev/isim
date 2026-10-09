// isim UIKit overlay: iOS 26 (Liquid Glass era) Swift value types over the Objective-C classes (self-authored).
// UISlider.TrackConfiguration / Tick are Swift structs, like Apple's, bridged to UISliderTrackConfiguration /
// UISliderTick (UIMoreControls.m); all values are fractions of the track (0...1).

@available(iOS 26.0, *)
extension UISlider {
    public struct TrackConfiguration: Hashable {
        public struct Tick: Hashable {
            public let position: Float
            public var title: String?
            public var image: UIImage?
            public init(position: Float, title: String? = nil, image: UIImage? = nil) {
                self.position = position; self.title = title; self.image = image
            }
        }
        public var allowsTickValuesOnly: Bool
        public var neutralValue: Float
        public var enabledRange: ClosedRange<Float>
        public let ticks: [Tick]
        public init(allowsTickValuesOnly: Bool = true, neutralValue: Float = 0, enabledRange: ClosedRange<Float> = 0...1, numberOfTicks: Int) {
            let n = max(0, numberOfTicks)
            self.init(allowsTickValuesOnly: allowsTickValuesOnly, neutralValue: neutralValue, enabledRange: enabledRange,
                      ticks: (0..<n).map { Tick(position: n > 1 ? Float($0) / Float(n - 1) : 0) })
        }
        public init(allowsTickValuesOnly: Bool = true, neutralValue: Float = 0, enabledRange: ClosedRange<Float> = 0...1, ticks: [Tick]) {
            self.allowsTickValuesOnly = allowsTickValuesOnly; self.neutralValue = neutralValue; self.enabledRange = enabledRange
            self.ticks = ticks.sorted { $0.position < $1.position }
        }
        init(_ c: __UISliderTrackConfiguration) {
            self.init(allowsTickValuesOnly: c.allowsTickValuesOnly, neutralValue: c.neutralValue,
                      enabledRange: c.minimumEnabledValue...max(c.minimumEnabledValue, c.maximumEnabledValue),
                      ticks: c.ticks.map { Tick(position: $0.position, title: $0.title, image: $0.image) })
        }
        var _objc: __UISliderTrackConfiguration {
            let c = __UISliderTrackConfiguration(ticks: ticks.map { __UISliderTick(position: $0.position, title: $0.title, image: $0.image) })
            c.allowsTickValuesOnly = allowsTickValuesOnly; c.neutralValue = neutralValue
            c.minimumEnabledValue = enabledRange.lowerBound; c.maximumEnabledValue = enabledRange.upperBound
            return c
        }
    }
    public var trackConfiguration: TrackConfiguration? {
        get { __trackConfiguration.map(TrackConfiguration.init) }
        set { __trackConfiguration = newValue?._objc }
    }
}

// UICornerRadius / UICornerConfiguration: Swift structs over the Objective-C classes (UIView.m), like Apple's.
@available(iOS 26.0, *)
public struct UICornerRadius: Hashable, CustomStringConvertible, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    enum Kind: Hashable { case fixed(Double), concentric(CGFloat?) }
    let kind: Kind
    public static func fixed(_ radius: Double) -> UICornerRadius { UICornerRadius(kind: .fixed(radius)) }
    public static func containerConcentric(minimum: CGFloat? = nil) -> UICornerRadius { UICornerRadius(kind: .concentric(minimum)) }
    init(kind: Kind) { self.kind = kind }
    public init(floatLiteral value: Double) { kind = .fixed(value) }
    public init(integerLiteral value: Int) { kind = .fixed(Double(value)) }
    public var description: String {
        switch kind {
        case .fixed(let r): return "\(r)"
        case .concentric(let m): return m.map { "containerConcentric(minimum: \($0))" } ?? "containerConcentric"
        }
    }
    var _objc: __UICornerRadius {
        switch kind {
        case .fixed(let r): return __UICornerRadius.fixedRadius(CGFloat(r))
        case .concentric(let m): return m.map { __UICornerRadius.containerConcentricRadius(withMinimum: $0) } ?? __UICornerRadius.containerConcentric()
        }
    }
}

@available(iOS 26.0, *)
public struct UICornerConfiguration: Hashable, CustomStringConvertible {
    let _objc: __UICornerConfiguration
    init(_ c: __UICornerConfiguration) { _objc = c }
    public static func == (a: UICornerConfiguration, b: UICornerConfiguration) -> Bool { a._objc.isEqual(b._objc) }
    public func hash(into h: inout Hasher) { h.combine(_objc.hash) }
    public var description: String { _objc.description }
    public static func corners(radius: UICornerRadius) -> UICornerConfiguration { .init(.init(radius: radius._objc)) }
    public static func corners(topLeftRadius: UICornerRadius? = nil, topRightRadius: UICornerRadius? = nil,
                               bottomLeftRadius: UICornerRadius? = nil, bottomRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        .init(.init(topLeftRadius: topLeftRadius?._objc, topRightRadius: topRightRadius?._objc,
                    bottomLeftRadius: bottomLeftRadius?._objc, bottomRightRadius: bottomRightRadius?._objc))
    }
    public static func capsule(maximumRadius: Double? = nil) -> UICornerConfiguration {
        .init(maximumRadius.map { __UICornerConfiguration.capsuleConfiguration(withMaximumRadius: CGFloat($0)) } ?? __UICornerConfiguration.capsule())
    }
    public static func uniformCorners(radius: UICornerRadius) -> UICornerConfiguration { .init(.init(uniformRadius: radius._objc)) }
    public static func uniformEdges(leftRadius: UICornerRadius, rightRadius: UICornerRadius) -> UICornerConfiguration {
        .init(.init(uniformLeftRadius: leftRadius._objc, uniformRightRadius: rightRadius._objc))
    }
    public static func uniformEdges(topRadius: UICornerRadius, bottomRadius: UICornerRadius) -> UICornerConfiguration {
        .init(.init(uniformTopRadius: topRadius._objc, uniformBottomRadius: bottomRadius._objc))
    }
    public static func uniformBottomRadius(_ radius: UICornerRadius, topLeftRadius: UICornerRadius? = nil, topRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        .init(.init(uniformBottomRadius: radius._objc, topLeftRadius: topLeftRadius?._objc, topRightRadius: topRightRadius?._objc))
    }
    public static func uniformLeftRadius(_ radius: UICornerRadius, topRightRadius: UICornerRadius? = nil, bottomRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        .init(.init(uniformLeftRadius: radius._objc, topRightRadius: topRightRadius?._objc, bottomRightRadius: bottomRightRadius?._objc))
    }
    public static func uniformRightRadius(_ radius: UICornerRadius, topLeftRadius: UICornerRadius? = nil, bottomLeftRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        .init(.init(uniformRightRadius: radius._objc, topLeftRadius: topLeftRadius?._objc, bottomLeftRadius: bottomLeftRadius?._objc))
    }
    public static func uniformTopRadius(_ radius: UICornerRadius, bottomLeftRadius: UICornerRadius? = nil, bottomRightRadius: UICornerRadius? = nil) -> UICornerConfiguration {
        .init(.init(uniformTopRadius: radius._objc, bottomLeftRadius: bottomLeftRadius?._objc, bottomRightRadius: bottomRightRadius?._objc))
    }
}

@available(iOS 26.0, *)
extension UIView {
    public var cornerConfiguration: UICornerConfiguration {
        get { UICornerConfiguration(__cornerConfiguration) }
        set { __cornerConfiguration = newValue._objc }
    }
}
