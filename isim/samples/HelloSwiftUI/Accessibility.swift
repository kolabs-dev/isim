// HelloSwiftUI, -accessibility: SwiftUI accessibility on isim's VoiceOver — headings with levels (View and Text),
// custom content (high importance read with the element, default importance in the rotor's More Content), custom rotors
// (ForEach ids, a namespace entry, a system rotor), accessibilityChildren (a chart's bars as elements),
// accessibilityRepresentation (a custom control read as a Slider), a linked group, @AccessibilityFocusState, and
// scroll, zoom and direct touch actions. It prints what the UI test checks.
import SwiftUI

private struct Fruit: Identifiable { let id: Int; let name: String; let favorite: Bool }
private let fruits = [Fruit(id: 1, name: "Apple", favorite: false), Fruit(id: 2, name: "Banana", favorite: true),
              Fruit(id: 3, name: "Cherry", favorite: false), Fruit(id: 4, name: "Date", favorite: true)]

struct AXDemo: View {
    @Namespace private var ns
    @State private var volume = 5.0
    @AccessibilityFocusState private var noteFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fruits").accessibilityHeading(.h2).accessibilityIdentifier("heading")
            Text("Details").accessibilityHeading(.h3).accessibilityIdentifier("heading3")
            HStack {
                ForEach(fruits) { f in Text(f.name).accessibilityIdentifier("fruit-\(f.id)") }
            }
            .accessibilityRotor("Favorites") {
                ForEach(fruits.filter(\.favorite)) { f in AccessibilityRotorEntry(f.name, id: f.id) }
            }
            .accessibilityRotor(.headings) { AccessibilityRotorEntry("Details", id: "details", in: ns) }
            Text("Origin").accessibilityRotorEntry(id: "details", in: ns).accessibilityIdentifier("origin")
            Text("Apple facts")
                .accessibilityCustomContent("Color", "Red", importance: .high)
                .accessibilityCustomContent("Grown in", "Kazakhstan")
                .accessibilityCustomContent(AccessibilityCustomContentKey("Calories", id: "kcal"), "52")
                .accessibilityIdentifier("facts")
            Rectangle().fill(Color.orange).frame(width: 200, height: 30)
                .accessibilityElement(children: .contain)
                .accessibilityChildren {
                    HStack { Text("Week 1").accessibilityValue("3 hours"); Text("Week 2").accessibilityValue("5 hours") }
                }
                .accessibilityIdentifier("chart")
            Capsule().fill(Color.blue).frame(width: 200 * volume / 10, height: 20)
                .accessibilityRepresentation {
                    Slider(value: $volume, in: 0...10, step: 1).accessibilityLabel("Volume")
                }
                .accessibilityIdentifier("volume")
            Text("Linked A").accessibilityLinkedGroup(id: "pair", in: ns).accessibilityIdentifier("linked-a")
            Text("Between").accessibilityIdentifier("between")
            Text("Linked B").accessibilityLinkedGroup(id: "pair", in: ns).accessibilityIdentifier("linked-b")
            Button("Focus note") { noteFocused = true }.accessibilityIdentifier("focus-note")
            Text("Note").accessibilityFocused($noteFocused).accessibilityIdentifier("note")
            Text("Feed").accessibilityScrollAction { edge in print("ax scroll \(edge)") }.accessibilityIdentifier("feed")
            Text("Map").accessibilityZoomAction { a in print("ax zoom \(a.direction == .zoomIn ? "in" : "out") \(String(format: "%.1f %.1f", a.location.x, a.location.y))") }
                .accessibilityIdentifier("map")
            Color.purple.frame(width: 120, height: 50)
                .onTapGesture { print("ax pad tapped") }
                .accessibilityElement().accessibilityLabel("Pad")
                .accessibilityDirectTouch(options: .silentOnTouch)
                .accessibilityIdentifier("pad")
        }
        .padding()
        .onChange(of: noteFocused) { print("ax note focused \(noteFocused)") }
        .onChange(of: volume) { print("ax volume \(Int(volume))") }
    }
}
