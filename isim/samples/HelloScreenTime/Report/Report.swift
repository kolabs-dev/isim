// The sample's Device Activity Report extension: a "Total Activity" scene with the minutes of each app.
import SwiftUI
import DeviceActivity
import ManagedSettings

@main
struct FocusReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { TotalActivityView(rows: $0) }
    }
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("Total Activity")
    let content: ([String]) -> TotalActivityView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [String] {
        var minutes: [String: Double] = [:]
        for await d in data {
            for await segment in d.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        minutes[app.application.localizedDisplayName ?? app.application.bundleIdentifier ?? "?", default: 0] += app.totalActivityDuration / 60
                    }
                }
            }
        }
        let rows = minutes.sorted { $0.key < $1.key }.map { "\($0.key): \(Int($0.value)) min" }
        print("str report \(rows.joined(separator: "; "))"); fflush(stdout)
        return rows
    }
}

struct TotalActivityView: View {
    let rows: [String]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Today").font(.headline)
            ForEach(rows, id: \.self) { Text($0).accessibilityIdentifier("report-\($0.split(separator: ":").first ?? "")") }
        }
    }
}
