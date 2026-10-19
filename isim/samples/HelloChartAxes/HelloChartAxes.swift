// Sample: Swift Charts axes and scales on isim (issue #246) — a log scale (chartYScale(domain:type: .log)), a square
// root scale, AxisValueLabel(format:) with a percent format, vertical labels (AxisValueLabelOrientation), label
// collisions resolved by truncating, a position range with padding (chartXScale(domain:range: .plotDimension(padding:)))
// and an axis built from AnyAxisContent. The test reads the label positions from the view tree.
import Charts
import SwiftUI

struct Point: Identifiable { let id = UUID(); let x: Double; let y: Double }
struct Item: Identifiable { let id = UUID(); let name: String; let value: Double }

struct ContentView: View {
    let growth = [Point(x: 1, y: 1), Point(x: 2, y: 10), Point(x: 3, y: 100), Point(x: 4, y: 1000)]
    let squares = [Point(x: 0, y: 0), Point(x: 1, y: 25), Point(x: 2, y: 100)]
    let shares = [Item(name: "North", value: 0.25), Item(name: "South", value: 0.5), Item(name: "East", value: 0.75)]
    let long = [Item(name: "Extraordinarily long", value: 3), Item(name: "Remarkably long", value: 5), Item(name: "Unusually long", value: 4),
                Item(name: "Considerably long", value: 2)]
    let showPercent = true

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Chart(growth) { LineMark(x: .value("x", $0.x), y: .value("y", $0.y)) }
                    .chartYScale(domain: 1...1000, type: .log)
                    .frame(height: 140).accessibilityIdentifier("log")
                Chart(squares) { PointMark(x: .value("x", $0.x), y: .value("y", $0.y)) }
                    .chartYScale(domain: 0...100, type: .squareRoot)
                    .chartYAxis { AxisMarks(values: [0, 25, 100]) }
                    .frame(height: 120).accessibilityIdentifier("sqrt")
                Chart(shares) { BarMark(x: .value("name", $0.name), y: .value("share", $0.value)) }
                    .chartYScale(domain: 0...1)
                    .chartYAxis {
                        AxisMarks(values: [0, 0.5, 1]) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                        }
                    }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel(orientation: .vertical) } }
                    .frame(height: 160).accessibilityIdentifier("percent")
                Chart(long) { BarMark(x: .value("name", $0.name), y: .value("v", $0.value)) }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel(collisionResolution: .truncate) } }
                    .frame(height: 120).accessibilityIdentifier("truncate")
                Chart(growth) { PointMark(x: .value("x", $0.x), y: .value("y", $0.y)) }
                    .chartXScale(domain: 0...4, range: .plotDimension(padding: 40))
                    .chartXAxis { axis }
                    .frame(height: 100).accessibilityIdentifier("padded")
            }
            .padding()
        }
        .onAppear { print("chart axes shown") }
    }
    /// an axis chosen at run time: type-erased
    var axis: AnyAxisContent {
        showPercent ? AnyAxisContent(AxisMarks(values: [0, 2, 4])) : AnyAxisContent(erasing: AxisMarks(values: .automatic))
    }
}

@main
struct HelloChartAxesApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
