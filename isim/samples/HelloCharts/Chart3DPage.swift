// HelloCharts -3d: a Chart3D scatter (issue #337) with each kind of 3D symbol (sphere, cube, cylinder, cone; sized and
// rotated, a metallic sphere), one style per series (foregroundStyle(by:)), the z axis' own values (chartZAxis), axis
// titles for x, y and z, and a tap selecting the nearest point (chartXSelection / chartYSelection / chartZSelection).
// The chart sits at a fixed place (x 16, y 120, 360 x 360) so tests/ui/test_charts_3d.py can measure it.
import SwiftUI
import Charts
import Spatial

struct Sample3D: Identifiable { let id: Int; let kind: String; let x: Double, y: Double, z: Double }

struct Chart3DPage: View {
    var body: some View {
        if #available(iOS 26.0, *) { Scatter3D() } else { Text("no 3D charts").onAppear { print("c3 unavailable") } }
    }
}

@available(iOS 26.0, *)
struct Scatter3D: View {
    let samples = [Sample3D(id: 0, kind: "A", x: -0.6, y: 0.6, z: -0.6), Sample3D(id: 1, kind: "A", x: 0.6, y: 0.6, z: 0.6),
                   Sample3D(id: 2, kind: "B", x: -0.6, y: -0.6, z: 0.6), Sample3D(id: 3, kind: "B", x: 0.6, y: -0.6, z: -0.6)]
    let symbols: [BasicChart3DSymbolShape] = [.sphere, .cube, .cylinder, .cone]
    @State private var x: Double?
    @State private var y: Double?
    @State private var z: Double?
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Chart3D(samples) { s in
                PointMark(x: .value("x", s.x), y: .value("y", s.y), z: .value("z", s.z))
                    .symbol(symbols[s.id])
                    .symbolSize(56)
                    .symbolRotation(Rotation3D(angle: .degrees(25), axis: .y))
                    .foregroundStyle(by: .value("Kind", s.kind))
                    .metalness(s.id == 0 ? 0.8 : 0)
                    .roughness(0.3)
            }
            .chartXScale(domain: -1...1).chartYScale(domain: -1...1).chartZScale(domain: -1...1)
            .chartForegroundStyleScale(["A": Color(red: 0.9, green: 0.2, blue: 0.2), "B": Color(red: 0.2, green: 0.4, blue: 0.95)])
            .chartZAxis { AxisMarks(values: [-1, 0, 1]) }
            .chartXAxisLabel("Width").chartYAxisLabel("Height").chartZAxisLabel("Depth")
            .chartXSelection(value: $x).chartYSelection(value: $y).chartZSelection(value: $z)
            .chart3DPose(Chart3DPose(azimuth: .degrees(30), inclination: .degrees(20)))
            .accessibilityIdentifier("chart3d")
            .frame(width: 360, height: 360)
            .offset(x: 16, y: 120)
            .onAppear { print("c3 shown symbols \(symbols.count)") }
            .onChange(of: [x, y, z]) { _, v in
                print("c3 selected " + v.map { $0.map { String(format: "%.1f", $0) } ?? "-" }.joined(separator: " "))
            }
        }
        .ignoresSafeArea()
    }
}
