// HelloFocusControls widget extension: two Control Center controls (iOS 18): a lamp toggle with a value provider and
// a counter button.
import WidgetKit
import SwiftUI
import AppIntents

@main
struct FocusLampControls: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            LampControl()
            CounterControl()
        }
    }
}

@available(iOS 18.0, *)
struct LampValue: ControlValueProvider {
    var previewValue: Bool { false }
    func currentValue() async throws -> Bool { lampOn }
}

@available(iOS 18.0, *)
struct LampControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.isim.samples.HelloFocusControls.lamp", provider: LampValue()) { isOn in
            ControlWidgetToggle(isOn: isOn, action: SetLampIntent()) {
                Label("Lamp", systemImage: "lightbulb.fill")
            } valueLabel: { on in
                Text(on ? "Bright" : "Off")
            }
            .tint(.orange)
        }
        .displayName("Desk Lamp")
        .description("Turns the lamp on and off")
    }
}

@available(iOS 18.0, *)
struct CounterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.isim.samples.HelloFocusControls.count") {
            ControlWidgetButton(action: CountIntent()) {
                Label("Count \(tapCount)", systemImage: "plus.circle.fill")
                    .controlWidgetActionHint("Count up")
            }
        }
        .displayName("Counter")
    }
}
