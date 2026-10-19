// Sample: Swift Charts mark styling on isim (issue #247) — lineStyle(by:) with chartLineStyleScale, mark offset,
// zIndex, clipShape, mask(content:), shadow and blur, annotations fitted inside the chart (AnnotationOverflowResolution),
// ChartProxy's style lookups, and NumberBins / DateBins. Each chart fills a known rect (axes hidden, fixed domains),
// so the test can find the marks' pixels; the bins and proxy print what the test checks.
import Charts
import SwiftUI

struct Sample: Identifiable { let id = UUID(); let x: Double; let y: Double; let kind: String }

let red = Color(red: 1, green: 0, blue: 0), blue = Color(red: 0, green: 0, blue: 1), green = Color(red: 0, green: 0.8, blue: 0)

struct ContentView: View {
    let lines = [Sample(x: 0, y: 7, kind: "Plan"), Sample(x: 10, y: 7, kind: "Plan"), Sample(x: 0, y: 3, kind: "Actual"), Sample(x: 10, y: 3, kind: "Actual")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // a dashed and a solid series
            Chart(lines) {
                LineMark(x: .value("x", $0.x), y: .value("y", $0.y)).lineStyle(by: .value("Kind", $0.kind)).foregroundStyle(by: .value("Kind", $0.kind))
            }
            .chartLineStyleScale(["Plan": StrokeStyle(lineWidth: 3, dash: [8, 6]), "Actual": StrokeStyle(lineWidth: 3)])
            .chartForegroundStyleScale(["Plan": red, "Actual": blue])
            .modifier(Fixed()).chartLegend(.hidden)
            .chartOverlay { proxy in
                Color.clear.onAppear {
                    print("proxy line plan=\(proxy.lineStyle(for: "Plan")?.dash ?? []) actual=\(proxy.lineStyle(for: "Actual")?.dash ?? [])"
                          + " domain=\(proxy.lineStyleDomain(dataType: String.self)) styles=\(proxy.foregroundStyleDomain(dataType: String.self))"
                          + " angle=\(Int(proxy.angle(at: CGPoint(x: proxy.plotSize.width, y: proxy.plotSize.height / 2)).degrees.rounded()))")
                }
            }
            .accessibilityIdentifier("lines")

            // zIndex, offset, clipShape, shadow
            Chart {
                RectangleMark(xStart: .value("x", 1), xEnd: .value("x", 4), yStart: .value("y", 1), yEnd: .value("y", 9)).foregroundStyle(blue).zIndex(1)
                RectangleMark(xStart: .value("x", 0), xEnd: .value("x", 5), yStart: .value("y", 0), yEnd: .value("y", 10)).foregroundStyle(red)
                RuleMark(x: .value("x", 6)).foregroundStyle(green).lineStyle(StrokeStyle(lineWidth: 4)).offset(x: 20)
                RectangleMark(xStart: .value("x", 8), xEnd: .value("x", 9), yStart: .value("y", 2), yEnd: .value("y", 8))
                    .foregroundStyle(Color.black).shadow(color: red, radius: 0, x: 8, y: 0)
            }
            .modifier(Fixed()).accessibilityIdentifier("effects")

            // a circle clip, a mask from other marks, a blur
            Chart {
                RectangleMark(xStart: .value("x", 0), xEnd: .value("x", 4), yStart: .value("y", 0), yEnd: .value("y", 10)).foregroundStyle(green)
                    .clipShape(Circle())
                AreaMark(x: .value("x", 5), y: .value("y", 10)).foregroundStyle(blue)
                    .mask { RectangleMark(xStart: .value("x", 5), xEnd: .value("x", 7), yStart: .value("y", 0), yEnd: .value("y", 10)) }
                AreaMark(x: .value("x", 10), y: .value("y", 10)).foregroundStyle(blue)
                    .mask { RectangleMark(xStart: .value("x", 5), xEnd: .value("x", 7), yStart: .value("y", 0), yEnd: .value("y", 10)) }
                RectangleMark(xStart: .value("x", 8), xEnd: .value("x", 10), yStart: .value("y", 3), yEnd: .value("y", 7)).foregroundStyle(red).blur(radius: 6)
            }
            .modifier(Fixed()).accessibilityIdentifier("clip")

            // annotations at the right edge: fitted inside the chart, or allowed to overflow
            Chart {
                PointMark(x: .value("x", 10), y: .value("y", 7))
                    .annotation(position: .trailing, overflowResolution: AnnotationOverflowResolution(x: .fit(to: .chart), y: .disabled)) {
                        Text("Fitted label").accessibilityIdentifier("fitted")
                    }
                PointMark(x: .value("x", 10), y: .value("y", 3))
                    .annotation(position: .trailing, overflowResolution: AnnotationOverflowResolution(x: .disabled, y: .disabled)) {
                        Text("Overflowing").accessibilityIdentifier("overflowing")
                    }
            }
            .modifier(Fixed()).accessibilityIdentifier("annotations")
        }
        .padding(.horizontal, 20)
        .onAppear { bins() }
    }

    func bins() {
        let numbers = NumberBins(data: [1.0, 2.5, 3.2, 7.9, 9.4, 12.0], desiredCount: 4)
        print("bins numbers=\(numbers.thresholds.map { Int($0) }) count=\(numbers.count) index7.9=\(numbers.index(for: 7.9)) first=\(Int(numbers[0].lowerBound))-\(Int(numbers[0].upperBound))")
        let fixed = NumberBins(size: 5, range: 0...20)
        print("bins size=\(fixed.thresholds) ints=\(NumberBins(thresholds: [0, 10, 20]).index(for: 15))")
        let start = Date(timeIntervalSince1970: 1767225600)                    // 2026-01-01 00:00 UTC
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let days = DateBins(unit: .day, range: start...start.addingTimeInterval(3 * 86400), calendar: cal)
        let hours = DateBins(timeInterval: 3600, range: start...start.addingTimeInterval(5 * 3600))
        print("bins days=\(days.count) hours=\(hours.count) index=\(days.index(for: start.addingTimeInterval(86400 + 60)))")
    }
}

/// a 360 x 110 chart whose plot is the whole chart: axes hidden, both domains 0...10
struct Fixed: ViewModifier {
    func body(content: Content) -> some View {
        content.chartXScale(domain: 0...10).chartYScale(domain: 0...10).chartXAxis(.hidden).chartYAxis(.hidden).frame(width: 330, height: 110)
    }
}

@main
struct HelloChartStylingApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
