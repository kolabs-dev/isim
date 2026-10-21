// HelloWidgets widget extension: an interactive counter (Button(intent:); also a Lock Screen circle), a ticker with a
// timeline and a Link, a configurable weather widget (AppIntentConfiguration: Edit Widget; a slow timeline, so the
// redacted placeholder shows first; Lock Screen rectangle and inline), a theme widget configured by a SiriKit intent
// (IntentConfiguration, with recommendations and images in their accented rendering modes), the delivery Live Activity
// (lock screen + Dynamic Island, stale content), on iOS 18 a timer Live Activity that also draws small, and on iOS 26
// headlines that reload on a widget push (WidgetPushHandler).
import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit
import Intents

@main
struct HelloWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CounterWidget()
        TickerWidget()
        WeatherWidget()
        ThemeWidget()
        DeliveryLiveActivity()
        if #available(iOS 18.0, *) { TimerLiveActivity() }
        if #available(iOS 26.0, *) { HeadlinesWidget() }
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

// MARK: - configured by a SiriKit intent

struct ThemeEntry: TimelineEntry { let date: Date; let color: ThemeColor; let title: String; let showsDate: Bool }
struct ThemeProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> ThemeEntry { ThemeEntry(date: Date(), color: .ocean, title: "My Theme", showsDate: false) }
    func getSnapshot(for configuration: ThemeIntent, in context: Context, completion: @escaping (ThemeEntry) -> Void) { completion(entry(configuration)) }
    func getTimeline(for configuration: ThemeIntent, in context: Context, completion: @escaping (Timeline<ThemeEntry>) -> Void) {
        let e = entry(configuration)
        NSLog("HelloWidgets extension: theme timeline (%@), color %ld, title %@, date %@", context.family.description, e.color.rawValue, e.title, e.showsDate ? "shown" : "hidden")
        completion(Timeline(entries: [e], policy: .never))
    }
    func recommendations() -> [IntentRecommendation<ThemeIntent>] {
        let forest = ThemeIntent(); forest.color = .forest; forest.title = "Forest"
        return [IntentRecommendation(intent: forest, description: "Forest")]
    }
    func entry(_ c: ThemeIntent) -> ThemeEntry {
        ThemeEntry(date: Date(), color: c.color == .unknown ? .ocean : c.color, title: c.title ?? "My Theme", showsDate: c.showsDate?.boolValue ?? false)
    }
}
struct ThemeView: View {
    let entry: ThemeEntry
    var background: Color {
        switch entry.color {
        case .sunrise: return Color(red: 0.95, green: 0.45, blue: 0.2)
        case .forest: return Color(red: 0.1, green: 0.45, blue: 0.25)
        default: return Color(red: 0.1, green: 0.3, blue: 0.6)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title).font(.headline).foregroundColor(.white).widgetAccentable()
            if entry.showsDate { Text(entry.date, style: .date).font(.caption).foregroundColor(.white) }
            Spacer(minLength: 0)
            HStack(spacing: 10) {                          /* the tinted Home Screen: the star in colour, the leaf grey */
                if #available(iOS 18.0, *) {
                    Image(systemName: "star.fill").widgetAccentedRenderingMode(.fullColor).font(.system(size: 34)).foregroundColor(.yellow)
                    Image(systemName: "leaf.fill").widgetAccentedRenderingMode(.desaturated).font(.system(size: 34)).foregroundColor(.green)
                } else {
                    Image(systemName: "star.fill").font(.system(size: 34)).foregroundColor(.yellow)
                    Image(systemName: "leaf.fill").font(.system(size: 34)).foregroundColor(.green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(background, for: .widget)
    }
}
struct ThemeWidget: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: "Theme", intent: ThemeIntent.self, provider: ThemeProvider()) { entry in
            ThemeView(entry: entry)
        }
        .configurationDisplayName("Theme")
        .description("Colours you choose")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - iOS 26: widget pushes

@available(iOS 26.0, *)
struct HeadlinesPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        NSLog("HelloWidgets extension: widget push token %@ for %@", pushInfo.token.map { String(format: "%02x", $0) }.joined(),
              widgets.map { "\($0.kind) \($0.family)" }.sorted().joined(separator: ", "))
    }
}
struct HeadlineEntry: TimelineEntry { let date: Date; let reloads: Int }
struct HeadlinesProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeadlineEntry { HeadlineEntry(date: Date(), reloads: 0) }
    func getSnapshot(in context: Context, completion: @escaping (HeadlineEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HeadlineEntry>) -> Void) {
        headlineReloads += 1
        NSLog("HelloWidgets extension: headlines timeline %ld", headlineReloads)
        completion(Timeline(entries: [HeadlineEntry(date: Date(), reloads: headlineReloads)], policy: .never))
    }
}
@available(iOS 26.0, *)
struct HeadlinesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Headlines", provider: HeadlinesProvider()) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text("HEADLINES").font(.caption.bold()).foregroundColor(.red)
                Text("Edition \(entry.reloads)").font(.title2.bold())
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(Color.white, for: .widget)
        }
        .configurationDisplayName("Headlines")
        .description("Updated by pushes")
        .supportedFamilies([.systemSmall])
        .pushHandler(HeadlinesPushHandler.self)
    }
}

// MARK: - Live Activities

@available(iOS 18.0, *)
struct TimerView: View {
    let context: ActivityViewContext<TimerAttributes>
    @Environment(\.activityFamily) var family
    var body: some View {
        let _ = NSLog("HelloWidgets extension: timer view (%@)", family == .small ? "small" : "medium")
        if family == .small {                              /* Apple Watch, CarPlay: just the time */
            HStack {
                Image(systemName: "timer").foregroundColor(.orange)
                Text("\(context.state.seconds) s").font(.headline)
            }
        } else {
            HStack {
                Text(context.attributes.name).font(.headline)
                Spacer()
                Text("\(context.state.seconds) s left").font(.title2.bold()).foregroundColor(.orange)
            }
            .padding(20)
        }
    }
}
@available(iOS 18.0, *)
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            TimerView(context: context).activityBackgroundTint(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.attributes.name) }
                DynamicIslandExpandedRegion(.trailing) { Text("\(context.state.seconds) s") }
            } compactLeading: {
                Image(systemName: "timer").foregroundColor(.orange)
            } compactTrailing: {
                Text("\(context.state.seconds)").foregroundColor(.orange)
            } minimal: {
                Image(systemName: "timer").foregroundColor(.orange)
            }
        }
        .supplementalActivityFamilies([.small])
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

// MARK: - Previews (`isim preview HelloWidgets.app --list`: they are in this extension)

#Preview("Counter", as: .systemSmall) {
    CounterWidget()
} timeline: {
    CounterEntry(date: Date(timeIntervalSince1970: 1_700_000_000), count: 1)
    CounterEntry(date: Date(timeIntervalSince1970: 1_700_000_600), count: 2)
    CounterEntry(date: Date(timeIntervalSince1970: 1_700_001_200), count: 3)
}

#Preview("Counter circle", as: .accessoryCircular, widget: { CounterWidget() }, timelineProvider: { CounterProvider() })

extension WeatherIntent {
    static var paris: WeatherIntent { let i = WeatherIntent(); i.city = .paris; i.feelsLike = true; return i }
}
#Preview("Weather", as: .systemMedium, using: WeatherIntent.paris) {
    WeatherWidget()
} timelineProvider: {
    WeatherProvider()
}

#Preview("Delivery", as: .content, using: DeliveryAttributes(orderNumber: "42")) {
    DeliveryLiveActivity()
} contentStates: {
    DeliveryAttributes.ContentState(minutes: 12, status: "On its way")
    DeliveryAttributes.ContentState(minutes: 2, status: "Arriving")
}

#Preview("Delivery island", as: .dynamicIsland(.expanded), using: DeliveryAttributes(orderNumber: "42")) {
    DeliveryLiveActivity()
} contentStates: {
    DeliveryAttributes.ContentState(minutes: 12, status: "On its way")
}

struct CounterView_Previews: PreviewProvider {           // iOS 14 style: WidgetPreviewContext
    static var previews: some View {
        CounterView(entry: CounterEntry(date: Date(), count: 7)).previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
