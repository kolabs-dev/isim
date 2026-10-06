// Sample: Swift Charts on isim — bar charts (annotations, stacking, custom style scale, horizontal),
// line/point/rule and area marks, a donut of sector marks with a legend, custom axis marks, a date axis
// and a rectangle heat map. Charts sit at fixed screen positions so the UI test can measure them.
import SwiftUI
import Charts

@main
struct HelloChartsApp: App {
    var body: some Scene { WindowGroup { ChartsGallery() } }
}

struct Sale: Identifiable { let id = UUID(); let name: String; let value: Double }
struct FruitSale: Identifiable { let id = UUID(); let day: String; let fruit: String; let count: Int }
enum Fruit: String, Plottable { case apples = "Apples", pears = "Pears", plums = "Plums" }

extension View {
    func at(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View { frame(width: w, height: h).offset(x: x, y: y) }
}

struct ChartsGallery: View {
    let sales = [Sale(name: "A", value: 10), Sale(name: "B", value: 20), Sale(name: "C", value: 40)]
    let fruit = [FruitSale(day: "Mon", fruit: "Apples", count: 10), FruitSale(day: "Mon", fruit: "Pears", count: 30),
                 FruitSale(day: "Tue", fruit: "Apples", count: 20), FruitSale(day: "Tue", fruit: "Pears", count: 10)]
    let points: [(Double, Double)] = [(0, 10), (1, 30), (2, 20), (3, 40)]
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            Chart(sales) { s in
                BarMark(x: .value("Name", s.name), y: .value("Value", s.value))
                    .annotation(position: .top) { Text("v\(Int(s.value))").font(.caption2) }
            }
            .chartYScale(domain: 0...40)
            .accessibilityIdentifier("bars").at(20, 60, 360, 150)

            Chart(fruit) { f in
                BarMark(x: .value("Day", f.day), y: .value("Count", f.count))
                    .foregroundStyle(by: .value("Fruit", f.fruit))
            }
            .chartForegroundStyleScale(["Apples": Color(red: 1, green: 0, blue: 0), "Pears": Color(red: 0, green: 0.6, blue: 0)])
            .accessibilityIdentifier("stacked").at(20, 220, 170, 150)

            Chart {
                SectorMark(angle: .value("Count", 1), innerRadius: .ratio(0.5)).foregroundStyle(by: .value("Fruit", Fruit.apples))
                SectorMark(angle: .value("Count", 1), innerRadius: .ratio(0.5)).foregroundStyle(by: .value("Fruit", Fruit.pears))
                SectorMark(angle: .value("Count", 2), innerRadius: .ratio(0.5)).foregroundStyle(by: .value("Fruit", Fruit.plums))
            }
            .accessibilityIdentifier("donut").at(210, 220, 170, 150)

            Chart {
                ForEach(points, id: \.0) { p in
                    LineMark(x: .value("x", p.0), y: .value("y", p.1))
                    PointMark(x: .value("x", p.0), y: .value("y", p.1)).foregroundStyle(Color(red: 1, green: 0.5, blue: 0))
                }
                RuleMark(y: .value("Average", 25)).foregroundStyle(Color(red: 1, green: 0, blue: 0))
            }
            .chartXScale(domain: 0...3).chartYScale(domain: 0...40)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .accessibilityIdentifier("line").at(20, 390, 170, 100)

            Chart {
                ForEach(points, id: \.0) { p in
                    AreaMark(x: .value("x", p.0), y: .value("y", p.1)).foregroundStyle(Color(red: 0, green: 0, blue: 1))
                }
            }
            .chartXScale(domain: 0...3).chartYScale(domain: 0...40)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .accessibilityIdentifier("area").at(210, 390, 170, 100)

            Chart {
                BarMark(x: .value("Count", 30), y: .value("Name", "Ann"))
                BarMark(x: .value("Count", 15), y: .value("Name", "Bob"))
            }
            .chartXScale(domain: 0...30).chartXAxis(.hidden)
            .accessibilityIdentifier("hbars").at(20, 510, 170, 100)

            Chart {
                ForEach(points, id: \.0) { p in
                    LineMark(x: .value("x", p.0), y: .value("y", p.1 * 2.5)).interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self) ?? -1)%") }
                }
                AxisMarks(position: .leading, values: [25, 75]) { value in
                    AxisTick()
                    AxisValueLabel { Text("q\(value.as(Int.self) ?? -1)") }
                }
            }
            .chartXAxis(.hidden)
            .accessibilityIdentifier("custom-axis").at(210, 510, 170, 100)

            Chart {
                ForEach(0..<5) { i in
                    BarMark(x: .value("Day", Date(timeIntervalSince1970: 1767225600 + Double(i) * 86400 + 43200), unit: .day), y: .value("Steps", 1000 * (i + 1)))
                }
            }
            .accessibilityIdentifier("dates").at(20, 630, 360, 100)

            Chart {
                RectangleMark(x: .value("col", "a"), y: .value("row", "1")).foregroundStyle(Color(red: 1, green: 0, blue: 0))
                RectangleMark(x: .value("col", "b"), y: .value("row", "1")).foregroundStyle(Color(red: 0, green: 0, blue: 1))
                RectangleMark(x: .value("col", "a"), y: .value("row", "2")).foregroundStyle(Color(red: 0, green: 0, blue: 1))
                RectangleMark(x: .value("col", "b"), y: .value("row", "2")).foregroundStyle(Color(red: 1, green: 0, blue: 0))
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .accessibilityIdentifier("heat").at(20, 750, 100, 60)

            Chart(fruit) { f in
                BarMark(x: .value("Day", f.day), y: .value("Count", f.count))
                    .foregroundStyle(by: .value("Fruit", f.fruit))
                    .position(by: .value("Fruit", f.fruit))
            }
            .chartForegroundStyleScale(["Apples": Color(red: 1, green: 0, blue: 0), "Pears": Color(red: 0, green: 0.6, blue: 0)])
            .chartLegend(.hidden).chartXAxis(.hidden).chartYAxis(.hidden).chartYScale(domain: 0...30)
            .accessibilityIdentifier("grouped").at(140, 750, 240, 60)

            // in a scroll view (no height offered) a chart takes its ideal height
            ScrollView {
                Chart { BarMark(x: .value("k", "a"), y: .value("v", 1)) }.accessibilityIdentifier("ideal")
            }
            .at(300, 820, 80, 30)
        }
        .ignoresSafeArea()
        .onAppear { print("charts shown") }
    }
}
