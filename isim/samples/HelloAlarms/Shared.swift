// HelloAlarms: what the app and its widget extension share: the alarms' metadata (the Live Activity's attributes
// are AlarmAttributes<TeaData>).
import AlarmKit

@available(iOS 26.0, *)
struct TeaData: AlarmMetadata {
    var tea: String
}
