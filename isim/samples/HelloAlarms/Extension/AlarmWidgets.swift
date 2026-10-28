// HelloAlarms widget extension: the tea timer's Live Activity (AlarmKit's AlarmAttributes with AlarmPresentationState
// as its content state): the countdown or "Paused" on the Lock Screen and in the Dynamic Island.
import WidgetKit
import SwiftUI
import ActivityKit
import AlarmKit

@main
struct HelloAlarmsWidgets: WidgetBundle {
    var body: some Widget {
        if #available(iOS 26.0, *) { TeaTimerLiveActivity() }
    }
}

@available(iOS 26.0, *)
func remaining(_ state: AlarmPresentationState) -> String {
    let left: TimeInterval
    switch state.mode {
    case .countdown(let c): left = max(0, c.fireDate.timeIntervalSinceNow)
    case .paused(let p): left = max(0, p.totalCountdownDuration - p.previouslyElapsedDuration)
    case .alert: left = 0
    @unknown default: left = 0
    }
    let s = Int(left.rounded(.up))
    return String(format: "%d:%02d", s / 60, s % 60)
}
@available(iOS 26.0, *)
func status(_ context: ActivityViewContext<AlarmAttributes<TeaData>>) -> String {
    let p = context.attributes.presentation
    switch context.state.mode {
    case .paused: return p.paused.map { String(localized: $0.title) } ?? "Paused"
    case .alert: return String(localized: p.alert.title)
    default: return p.countdown.map { String(localized: $0.title) } ?? "Timer"
    }
}

@available(iOS 26.0, *)
struct TeaTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<TeaData>.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text(status(context)).font(.headline)
                    Text(context.attributes.metadata?.tea ?? "Tea").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Text(remaining(context.state)).font(.title.bold()).foregroundColor(context.attributes.tintColor)
            }
            .padding(20)
            .activityBackgroundTint(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(status(context)).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { Text(remaining(context.state)).font(.headline).foregroundColor(context.attributes.tintColor) }
            } compactLeading: {
                Image(systemName: "timer").foregroundColor(context.attributes.tintColor)
            } compactTrailing: {
                Text(remaining(context.state)).foregroundColor(context.attributes.tintColor)
            } minimal: {
                Image(systemName: "timer").foregroundColor(context.attributes.tintColor)
            }
        }
    }
}
