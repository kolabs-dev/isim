// HelloWidgets widget extension: an interactive counter (Button(intent:); also a Lock Screen circle), a ticker with a
// timeline and a Link, a configurable weather widget (AppIntentConfiguration: Edit Widget; a slow timeline, so the
// redacted placeholder shows first; Lock Screen rectangle and inline), and the delivery Live Activity (lock screen +
// Dynamic Island, stale content).
import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

@main
struct HelloWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CounterWidget()
        TickerWidget()
        WeatherWidget()
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
            CounterView(entry: entry)
        }
        .configurationDisplayName("Counter")
        .description("Tap +1 to count up")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
struct CounterView: View {
    let entry: CounterEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var mode
    var body: some View {
        let _ = NSLog("HelloWidgets extension: counter view (%@), rendering mode %@", family.description, "\(mode)")
        if family == .accessoryCircular {                   /* the Lock Screen: on the system's translucent disc */
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "plus.circle").font(.caption)
                    Text("\(entry.count)").font(.title.bold())
                }
            }
            .containerBackground(Color.clear, for: .widget)
        } else {
            VStack(spacing: 6) {
                Text("COUNT").font(.caption).foregroundColor(.white.opacity(0.8))
                Text("\(entry.count)").font(.system(size: 46, weight: .bold)).foregroundColor(.white)
                    .widgetAccentable()                          /* the tinted Home Screen: in the tint */
                Button(intent: IncrementIntent()) {
                    Text("+1").font(.headline).foregroundColor(.blue).frame(maxWidth: .infinity, minHeight: 34)
                        .background(Color.white).cornerRadius(17)
                }
            }
            .containerBackground(Color.blue, for: .widget)
        }
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
                Link(destination: URL(string: "hellowidgets://ticker/details")!) {
                    Text("Details").font(.headline).foregroundColor(.white).padding(.horizontal, 12).frame(height: 34)
                        .background(Color.orange).cornerRadius(17)
                }
            }
            .containerBackground(Color.white, for: .widget)
        }
        .configurationDisplayName("Ticker")
        .description("A timeline with three entries")
        .supportedFamilies([.systemMedium])
    }
}

struct WeatherEntry: TimelineEntry { let date: Date; let city: City; let feelsLike: Bool }
struct WeatherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: Date(), city: .cupertino, feelsLike: false) }
    func snapshot(for configuration: WeatherIntent, in context: Context) async -> WeatherEntry {
        NSLog("HelloWidgets extension: weather snapshot (%@), preview %@", context.family.description, context.isPreview ? "yes" : "no")
        return WeatherEntry(date: Date(), city: configuration.city, feelsLike: configuration.feelsLike)
    }
    func timeline(for configuration: WeatherIntent, in context: Context) async -> Timeline<WeatherEntry> {
        NSLog("HelloWidgets extension: weather timeline (%@), %@, feels like %@", context.family.description, configuration.city.name, configuration.feelsLike ? "on" : "off")
        try? await Task.sleep(nanoseconds: 1_500_000_000)     /* a slow forecast request: the placeholder shows meanwhile */
        return Timeline(entries: [WeatherEntry(date: Date(), city: configuration.city, feelsLike: configuration.feelsLike)], policy: .never)
    }
}
struct WeatherView: View {
    let entry: WeatherEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    var body: some View {
        let _ = NSLog("HelloWidgets extension: weather view (%@), background %@", family.description, showsBackground ? "shown" : "removed")
        content
            .containerBackground(Color(red: 0.2, green: 0.5, blue: 0.95), for: .widget)
            .widgetURL(URL(string: "hellowidgets://weather/\(entry.city.rawValue)"))
    }
    @ViewBuilder var content: some View {
        switch family {
        case .accessoryInline:
            Label("\(entry.city.name) \(entry.city.temperature)°", systemImage: "sun.max.fill")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill").font(.title2)
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.city.name).font(.headline)
                    Text("\(entry.city.temperature)° Sunny").font(.subheadline)
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.city.name).font(.headline).foregroundColor(.white)
                Text("\(entry.city.temperature)°").font(.system(size: 44, weight: .semibold)).foregroundColor(.white)
                if entry.feelsLike { Text("Feels like \(entry.city.temperature - 2)°").font(.caption).foregroundColor(.white) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Weather", intent: WeatherIntent.self, provider: WeatherProvider()) { entry in
            WeatherView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("The weather in a city you choose")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text("Order \(context.attributes.orderNumber)").font(.headline)
                    Text(context.isStale ? "Updating…" : context.state.status).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(context.state.minutes) min").font(.title.bold()).foregroundColor(.green)
            }
            .padding(20)
            .activityBackgroundTint(context.isStale ? Color(white: 0.6) : Color.white)   /* stale: grey */
            .widgetURL(URL(string: "hellowidgets://delivery/\(context.attributes.orderNumber)"))
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
