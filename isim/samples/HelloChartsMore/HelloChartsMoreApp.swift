// Sample: more Swift Charts on isim — point symbols (basic shapes, symbol(by:), symbolSize(by:), a custom
// ChartSymbolShape, symbol { view }), axis titles with positions, chartOverlay / chartBackground with ChartProxy,
// selection (chartXSelection), a scrolling chart (chartScrollableAxes, chartXVisibleDomain, chartScrollPosition,
// value-aligned targets), chartPlotStyle, iOS 18 vectorized plots (BarPlot, PointPlot, function LinePlot / AreaPlot,
// SectorPlot) and, on iOS 26, Chart3D (points, a rule, a rectangle and a surface). Charts sit at fixed screen
// positions so the UI test can measure them; values the test checks are printed.
import SwiftUI
import Charts

@main
struct HelloChartsMoreApp: App {
    var body: some Scene { WindowGroup { MoreCharts() } }
}

extension View {
    func at(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View { frame(width: w, height: h).offset(x: x, y: y) }
}

/// A bow tie: a custom ChartSymbolShape.
struct Bowtie: ChartSymbolShape {
    var perceptualUnitRect: CGRect { CGRect(x: 0, y: 0, width: 1, height: 1) }
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addLines([CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY)])
        p.closeSubpath()
        return p
    }
}

struct Item: Identifiable { let id = UUID(); let name: String; let value: Double; let kind: String }

struct MoreCharts: View {
    @State private var selected: String? = nil
    @State private var scrollX: Int = 0
    let items = ["A", "B", "C", "D", "E", "F"].enumerated().map { Item(name: $1, value: Double(($0 + 1) * 10), kind: $0 % 2 == 0 ? "even" : "odd") }
    let red = Color(red: 1, green: 0, blue: 0), green = Color(red: 0, green: 0.7, blue: 0), blue = Color(red: 0, green: 0, blue: 1)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            symbols.accessibilityIdentifier("symbols").at(20, 50, 170, 110)
            titles.accessibilityIdentifier("titles").at(210, 50, 170, 110)
            selection.accessibilityIdentifier("selection").at(20, 175, 360, 140)
            scrolling.accessibilityIdentifier("scrolling").at(20, 330, 360, 100)
            plotStyle.accessibilityIdentifier("plotstyle").at(20, 445, 170, 100)
            vectorized.at(210, 445, 170, 100)
            functions.at(20, 560, 170, 100)
            sectors.at(210, 560, 170, 100)
            threeD.at(20, 675, 360, 150)
        }
        .ignoresSafeArea()
        .onAppear { print("more charts shown") }
    }

    // basic shapes at x = 1, 2, 3 (square, triangle, diamond: 200 sq pt), a custom shape at 4, a view at 5
    var symbols: some View {
        Chart {
            PointMark(x: .value("x", 1), y: .value("y", 1)).symbol(.square).symbolSize(200).foregroundStyle(blue)
            PointMark(x: .value("x", 2), y: .value("y", 1)).symbol(.triangle).symbolSize(200).foregroundStyle(blue)
            PointMark(x: .value("x", 3), y: .value("y", 1)).symbol(.diamond).symbolSize(200).foregroundStyle(blue)
            PointMark(x: .value("x", 4), y: .value("y", 1)).symbol(Bowtie()).symbolSize(200).foregroundStyle(green)
            PointMark(x: .value("x", 5), y: .value("y", 1)).symbol { Rectangle().fill(red).frame(width: 12, height: 12) }
            // symbol(by:) through chartSymbolScale, sized by value: small (10) and big (90) circles at y = 0.5
            PointMark(x: .value("x", 2), y: .value("y", 0.4)).symbol(by: .value("k", "round")).symbolSize(by: .value("v", 10)).foregroundStyle(blue)
            PointMark(x: .value("x", 4), y: .value("y", 0.4)).symbol(by: .value("k", "round")).symbolSize(by: .value("v", 90)).foregroundStyle(blue)
        }
        .chartSymbolScale(["round": .circle])
        .chartSymbolSizeScale(range: 30...400)
        .chartXScale(domain: 0...6).chartYScale(domain: 0...1.5)
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
    }

    var titles: some View {
        Chart(items) { BarMark(x: .value("Name", $0.name), y: .value("Value", $0.value)) }
            .chartXAxisLabel("Letters", position: .bottom, alignment: .trailing)
            .chartYAxisLabel("Amount", position: .leading)
    }

    // selection (drag: a rule at the selected bar), an overlay dot at (C, 30) placed with the proxy, a pale yellow plot
    var selection: some View {
        Chart(items) { item in
            BarMark(x: .value("Name", item.name), y: .value("Value", item.value)).foregroundStyle(item.name == selected ? red : blue)
            if let s = selected, s == item.name { RuleMark(x: .value("Name", s)).foregroundStyle(green) }
        }
        .chartYScale(domain: 0...60)
        .chartXSelection(value: $selected)
        .onChange(of: selected) { _, v in print("selected \(v ?? "nil")") }
        .chartBackground { proxy in
            GeometryReader { geo in
                if let f = proxy.plotFrame {
                    let r = geo[f]
                    Color(red: 1, green: 1, blue: 0.6).frame(width: r.width, height: r.height).offset(x: r.minX, y: r.minY)
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let f = proxy.plotFrame, let x = proxy.position(forX: "C"), let y = proxy.position(forY: 30.0) {
                    let r = geo[f]
                    Circle().fill(Color(red: 1, green: 0.5, blue: 0)).frame(width: 10, height: 10).position(x: r.minX + x, y: r.minY + y)
                        .onAppear {
                            let back: String = proxy.value(atX: x) ?? "?"
                            let v: Double = proxy.value(atY: y) ?? -1
                            print("proxy plot \(Int(r.minX)) \(Int(r.minY)) \(Int(r.width)) \(Int(r.height)) C at \(Int(x)) 30 at \(Int(y)) back \(back) \(Int(v.rounded()))")
                        }
                }
            }
        }
    }

    // 30 bars, 10 visible; scrolls in steps of 5
    var scrolling: some View {
        Chart(0..<30, id: \.self) { i in
            BarMark(x: .value("i", i), y: .value("v", i % 2 == 0 ? 10 : 5)).foregroundStyle(i < 10 ? blue : red)
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 10)
        .chartScrollPosition(x: $scrollX)
        .chartScrollTargetBehavior(.valueAligned(unit: 5))
        .chartYAxis(.hidden)
        .onChange(of: scrollX) { _, v in print("scroll x \(v)") }
    }

    var plotStyle: some View {
        Chart { LineMark(x: .value("x", 0), y: .value("y", 0)); LineMark(x: .value("x", 1), y: .value("y", 1)) }
            .chartPlotStyle { plot in plot.background(Color(red: 1, green: 1, blue: 0)).border(blue, width: 3) }
            .chartXAxis(.hidden).chartYAxis(.hidden)
    }

    @ViewBuilder var vectorized: some View {
        if #available(iOS 18.0, *) {
            Chart {
                BarPlot(items, x: .value("Name", \.name), y: .value("Value", \.value)).foregroundStyle(by: .value("Kind", \.kind))
                PointPlot(items, x: .value("Name", \.name), y: .value("Value", \.value)).foregroundStyle(green)
            }
            .chartForegroundStyleScale(["even": red, "odd": blue])
            .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden).chartYScale(domain: 0...60)
            .accessibilityIdentifier("vectorized")
            .onAppear { print("vectorized plots shown") }
        } else { Text("no vectorized plots") }
    }

    // y = sin(x) and the band between -0.5 and 0.5 over -pi ... pi
    @ViewBuilder var functions: some View {
        if #available(iOS 18.0, *) {
            Chart {
                AreaPlot(x: "x", yStart: "lo", yEnd: "hi") { _ in (yStart: -0.5, yEnd: 0.5) }.foregroundStyle(Color(red: 0.8, green: 0.8, blue: 1))
                LinePlot(x: "x", y: "y") { sin($0) }.foregroundStyle(red).lineStyle(StrokeStyle(lineWidth: 3))
            }
            .chartXScale(domain: -Double.pi...Double.pi).chartYScale(domain: -1...1)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .accessibilityIdentifier("functions")
        } else { Text("no function plots") }
    }

    @ViewBuilder var sectors: some View {
        if #available(iOS 18.0, *) {
            Chart { SectorPlot(items.prefix(2), angle: .value("Value", \.value)).foregroundStyle(by: .value("Name", \.name)) }
                .chartForegroundStyleScale(["A": red, "B": blue])
                .chartLegend(.hidden)
                .accessibilityIdentifier("sectors")
        } else { Text("no sector plots") }
    }

    @ViewBuilder var threeD: some View {
        if #available(iOS 26.0, *) { ThreeD() } else { Text("no 3D charts").accessibilityIdentifier("no3d").onAppear { print("3D unavailable") } }
    }
}

@available(iOS 26.0, *)
struct ThreeD: View {
    @State private var pose: Chart3DPose = .front
    var body: some View {
        Chart3D {
            SurfacePlot(x: "x", y: "y", z: "z") { x, z in 0.4 * x * z }.foregroundStyle(.heightBased)
            PointMark(x: .value("x", 0.0), y: .value("y", 1.0), z: .value("z", 0.0)).foregroundStyle(Color(red: 1, green: 0, blue: 0)).symbolSize(300)
            RuleMark(x: .value("x", -1.0..<1.0), y: .value("y", -1.0), z: .value("z", 0.0)).foregroundStyle(Color(red: 0, green: 0, blue: 0))
        }
        .chartXScale(domain: -1...1).chartYScale(domain: -1...1).chartZScale(domain: -1...1)
        .chart3DPose($pose)
        .accessibilityIdentifier("chart3d")
        .onAppear { print("3D shown") }
        .onChange(of: pose) { _, p in print("pose \(Int(p.azimuth.degrees.rounded())) \(Int(p.inclination.degrees.rounded()))") }
    }
}
