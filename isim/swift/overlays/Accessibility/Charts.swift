// isim Accessibility (issue #425): the Swift forms of the audio graph API, over the Objective-C classes
// (frameworks/Accessibility/AXChart.m): ranges, gridlines as Doubles, AXDataPoint.Value and the chart initializers.
import Foundation

@available(iOS 15.0, *)
extension AXNumericDataAxisDescriptor {
    public convenience init(title: String, range: ClosedRange<Double>, gridlinePositions: [Double],
                            valueDescriptionProvider: @escaping (Double) -> String) {
        self.init(__title: title, lowerBound: range.lowerBound, upperBound: range.upperBound,
                  gridlinePositions: gridlinePositions.map { NSNumber(value: $0) }, valueDescriptionProvider: valueDescriptionProvider)
    }
    public convenience init(attributedTitle: NSAttributedString, range: ClosedRange<Double>, gridlinePositions: [Double],
                            valueDescriptionProvider: @escaping (Double) -> String) {
        self.init(__attributedTitle: attributedTitle, lowerBound: range.lowerBound, upperBound: range.upperBound,
                  gridlinePositions: gridlinePositions.map { NSNumber(value: $0) }, valueDescriptionProvider: valueDescriptionProvider)
    }
    /// the axis' bounds
    public var range: ClosedRange<Double> {
        get { min(__lowerBound, __upperBound)...max(__lowerBound, __upperBound) }
        set { __lowerBound = newValue.lowerBound; __upperBound = newValue.upperBound }
    }
    public var gridlinePositions: [Double] {
        get { __gridlinePositions.map(\.doubleValue) }
        set { __gridlinePositions = newValue.map { NSNumber(value: $0) } }
    }
}

@available(iOS 15.0, *)
extension AXDataPoint {
    /// a value of a data point on an axis
    public enum Value: Sendable, Hashable {
        case number(Double)
        case category(String)
        var objc: AXDataPointValue {
            switch self {
            case .number(let n): return AXDataPointValue(__number: n)
            case .category(let c): return AXDataPointValue(__category: c)
            }
        }
        init(_ v: AXDataPointValue) { self = v.category.map { .category($0) } ?? .number(v.number) }
    }
    public convenience init(x: Double, y: Double?, additionalValues: [AXDataPoint.Value] = [], label: String? = nil) {
        self.init(__x: AXDataPointValue(__number: x), y: y.map { AXDataPointValue(__number: $0) },
                  additionalValues: additionalValues.map(\.objc), label: label)
    }
    public convenience init(x: String, y: Double?, additionalValues: [AXDataPoint.Value] = [], label: String? = nil) {
        self.init(__x: AXDataPointValue(__category: x), y: y.map { AXDataPointValue(__number: $0) },
                  additionalValues: additionalValues.map(\.objc), label: label)
    }
    public var additionalValues: [AXDataPoint.Value] {
        get { __additionalValues.map(Value.init) }
        set { __additionalValues = newValue.map(\.objc) }
    }
}

@available(iOS 15.0, *)
extension AXChartDescriptor {
    public convenience init(title: String? = nil, summary: String? = nil, xAxis: any AXDataAxisDescriptor, yAxis: AXNumericDataAxisDescriptor? = nil,
                            additionalAxes: [any AXDataAxisDescriptor] = [], series: [AXDataSeriesDescriptor]) {
        self.init(__title: title, summary: summary, xAxisDescriptor: xAxis, yAxisDescriptor: yAxis, additionalAxes: additionalAxes, series: series)
    }
    public convenience init(attributedTitle: NSAttributedString? = nil, summary: String? = nil, xAxis: any AXDataAxisDescriptor,
                            yAxis: AXNumericDataAxisDescriptor? = nil, additionalAxes: [any AXDataAxisDescriptor] = [],
                            series: [AXDataSeriesDescriptor]) {
        self.init(__attributedTitle: attributedTitle, summary: summary, xAxisDescriptor: xAxis, yAxisDescriptor: yAxis,
                  additionalAxes: additionalAxes, series: series)
    }
}
