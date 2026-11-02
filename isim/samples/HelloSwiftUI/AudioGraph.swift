// HelloSwiftUI, -audiograph: audio graphs on isim's VoiceOver (issue #425). A bar chart of monthly rainfall gets a chart
// descriptor through SwiftUI's accessibilityChartDescriptor(_:) (AXChartDescriptorRepresentable), and a UIKit view
// conforming to AXChart a line chart of temperatures (a continuous series on a numeric x axis). VoiceOver's rotor offers
// Audio Graph: Describe Chart, Play Audio Graph and Chart Details. The Live button plays a changing value with
// AXLiveAudioGraph. It prints what the UI test checks.
import SwiftUI
import UIKit
import Accessibility

private let rain: [(String, Double)] = [("Jan", 78), ("Feb", 55), ("Mar", 62), ("Apr", 40), ("May", 31), ("Jun", 12)]

private struct RainChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: "Month", categoryOrder: rain.map(\.0))
        let y = AXNumericDataAxisDescriptor(title: "Rainfall", range: 0...100, gridlinePositions: [0, 50, 100]) { "\(Int($0)) millimeters" }
        let series = AXDataSeriesDescriptor(name: "Rainfall", isContinuous: false,
                                            dataPoints: rain.map { AXDataPoint(x: $0.0, y: $0.1) })
        return AXChartDescriptor(title: "Rainfall in 2026", summary: "Rainfall falls from January to June",
                                 xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}

/// a UIKit line chart: the AXChart protocol on the view itself
final class TemperatureView: UIView, AXChart {
    var accessibilityChartDescriptor: AXChartDescriptor?
    let temps: [Double] = [4, 6, 11, 15, 19, 23, 25]
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        isAccessibilityElement = true
        accessibilityLabel = "Temperatures"
        accessibilityIdentifier = "temperatures"
        let x = AXNumericDataAxisDescriptor(title: "Day", range: 1...7, gridlinePositions: []) { "day \(Int($0))" }
        let y = AXNumericDataAxisDescriptor(title: "Temperature", range: 0...30, gridlinePositions: [0, 10, 20, 30]) { "\(Int($0)) degrees" }
        let s = AXDataSeriesDescriptor(name: "Daily high", isContinuous: true,
                                       dataPoints: temps.enumerated().map { AXDataPoint(x: Double($0.offset + 1), y: $0.element) })
        accessibilityChartDescriptor = AXChartDescriptor(title: "Daily highs", summary: nil, xAxis: x, yAxis: y, series: [s])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let p = UIBezierPath()
        for (i, t) in temps.enumerated() {
            let pt = CGPoint(x: 10 + CGFloat(i) * (bounds.width - 20) / CGFloat(temps.count - 1), y: bounds.height - 10 - CGFloat(t / 30) * (bounds.height - 20))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        UIColor.systemRed.setStroke(); p.lineWidth = 3; p.stroke()
    }
}
private struct TemperatureChart: UIViewRepresentable {
    func makeUIView(context: Context) -> TemperatureView { TemperatureView(frame: .zero) }
    func updateUIView(_ uiView: TemperatureView, context: Context) {}
}

struct AudioGraphDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rainfall in 2026").font(.headline)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(rain, id: \.0) { m in
                    VStack {
                        RoundedRectangle(cornerRadius: 4).fill(Color.blue).frame(width: 34, height: m.1 * 1.6)
                        Text(m.0).font(.caption)
                    }
                }
            }
            .frame(height: 180, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rainfall chart")
            .accessibilityChartDescriptor(RainChart())
            .accessibilityIdentifier("rain")
            Text("Daily highs").font(.headline)
            TemperatureChart().frame(height: 120)
            Button("Live") {
                AXLiveAudioGraph.start()
                for (i, v) in [0.2, 0.5, 0.9].enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(i)) { AXLiveAudioGraph.updateValue(v) }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { AXLiveAudioGraph.stop(); print("ax live done") }
            }
            .accessibilityIdentifier("live")
            Spacer()
        }
        .padding()
        .onAppear {
            let d = RainChart().makeChartDescriptor()
            let p = d.series[0].dataPoints[0]
            print("ax chart \(d.title ?? "-") x=\(d.xAxis.title) y=\(d.yAxis?.range.upperBound ?? 0) first=\(p.xValue.category ?? "-") \(p.yValue?.number ?? 0)")
        }
    }
}
