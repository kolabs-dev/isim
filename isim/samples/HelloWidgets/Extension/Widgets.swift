// HelloWidgets widget extension: an interactive counter (Button(intent:)), a ticker with a timeline, and the
// delivery Live Activity (lock screen + Dynamic Island).
import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

@main
struct HelloWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CounterWidget()
        TickerWidget()
        DeliveryLiveActivity()
    }
}

struct CounterEntry: TimelineEntry { let date: Date; let count: Int }
struct CounterProvider: TimelineProvider {
    func placeholder(in context: Context) -> CounterEntry { CounterEntry(date: Date(), count: 0) }
    func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) { completion(CounterEntry(date: Date(), count: sharedCount)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
        NSLog("HelloWidgets extension: counter timeline (%@), count %ld", context.family.description, sharedCount)
        completion(Timeline(entries: [CounterEntry(date: Date(), count: sharedCount)], policy: .never))
    }
}
struct CounterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Counter", provider: CounterProvider()) { entry in
            VStack(spacing: 6) {
                Text("COUNT").font(.caption).foregroundColor(.white.opacity(0.8))
                Text("\(entry.count)").font(.system(size: 46, weight: .bold)).foregroundColor(.white)
                Button(intent: IncrementIntent()) {
                    Text("+1").font(.headline).foregroundColor(.blue).frame(maxWidth: .infinity, minHeight: 34)
                        .background(Color.white).cornerRadius(17)
                }
            }
            .containerBackground(Color.blue, for: .widget)
        }
        .configurationDisplayName("Counter")
        .description("Tap +1 to count up")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TickEntry: TimelineEntry { let date: Date; let label: String }
struct TickerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TickEntry { TickEntry(date: Date(), label: "Tick") }
    func getSnapshot(in context: Context, completion: @escaping (TickEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TickEntry>) -> Void) {
        let now = Date()
        let entries = (0..<3).map { TickEntry(date: now.addingTimeInterval(Double($0) * 2), label: "Tick \($0 + 1)") }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
struct TickerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Ticker", provider: TickerProvider()) { entry in
            HStack {
                Image(systemName: "clock.fill").font(.largeTitle).foregroundColor(.orange)
                Text(entry.label).font(.title.bold())
                Spacer()
            }
            .containerBackground(Color.white, for: .widget)
        }
        .configurationDisplayName("Ticker")
        .description("A timeline with three entries")
        .supportedFamilies([.systemMedium])
    }
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text("Order \(context.attributes.orderNumber)").font(.headline)
                    Text(context.state.status).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(context.state.minutes) min").font(.title.bold()).foregroundColor(.green)
            }
            .padding(20)
            .activityBackgroundTint(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("Order \(context.attributes.orderNumber)").font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { Text("\(context.state.minutes) min").font(.headline).foregroundColor(.green) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(context.state.status).font(.subheadline)
                        Rectangle().fill(Color.green).frame(height: 6)    /* full width: shows the horizontal margins */
                    }
                }
            } compactLeading: {
                Image(systemName: "clock.fill").foregroundColor(.green)
            } compactTrailing: {
                Text("\(context.state.minutes)m").font(.caption.bold()).foregroundColor(.green)
            } minimal: {
                Text("\(context.state.minutes)").foregroundColor(.green)
            }
            .contentMargins(.horizontal, 16, for: .expanded)
        }
    }
}
