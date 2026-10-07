// Sample: SwiftUI presentations on isim — alerts with text fields, popovers (anchored with an arrow on iPad, sheets on
// iPhone unless presentationCompactAdaptation keeps them), detent sheets with background interaction and
// interactiveDismissDisabled, presentationSizing (iOS 18, iPad), a zoom fullScreenCover (iOS 18) and the inspector
// (a trailing column on iPad).
import SwiftUI

@main
struct HelloSheetsApp: App {
    var body: some Scene { WindowGroup { SheetsView() } }
}

struct SheetsView: View {
    @State private var showAlert = false
    @State private var name = ""
    @State private var secret = ""
    @State private var showPopover = false
    @State private var showCompact = false
    @State private var showInteractive = false
    @State private var showLocked = false
    @State private var showForm = false
    @State private var showZoom = false
    @State private var showInspector = false
    @State private var bumps = 0
    @Namespace private var ns
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Button("Alert with fields") { showAlert = true }.accessibilityIdentifier("open-alert")
                    Button("Popover") { showPopover = true }.accessibilityIdentifier("open-popover")
                        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                            Text("Popover content").padding().accessibilityIdentifier("popover-text")
                        }
                    Button("Compact popover") { showCompact = true }.accessibilityIdentifier("open-compact")
                        .popover(isPresented: $showCompact) {
                            Text("Stays a popover").padding().presentationCompactAdaptation(.popover).accessibilityIdentifier("compact-text")
                        }
                    Button("Interactive sheet") { showInteractive = true }.accessibilityIdentifier("open-interactive")
                    Button("Locked sheet") { showLocked = true }.accessibilityIdentifier("open-locked")
                    Button("Form sheet") { showForm = true }.accessibilityIdentifier("open-form")
                    Button("Inspector") { showInspector.toggle() }.accessibilityIdentifier("toggle-inspector")
                    Button("Bump \(bumps)") { bumps += 1; print("bump \(bumps)") }.accessibilityIdentifier("bump")
                    Button { showZoom = true } label: {
                        Color.purple.frame(width: 60, height: 60).cornerRadius(10).modifier(ZoomSource(ns: ns))
                    }.accessibilityIdentifier("open-zoom")
                    Text("Name: \(name)").accessibilityIdentifier("name-label")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Sheets")
            .navigationBarTitleDisplayMode(.inline)
        }
        .inspector(isPresented: $showInspector) {
            VStack(alignment: .leading) { Text("Inspector").font(.headline); Text("Details here") }
                .inspectorColumnWidth(280)
                .accessibilityIdentifier("inspector-content")
        }
        .alert("Sign in", isPresented: $showAlert) {
            TextField("Name", text: $name)
            SecureField("Password", text: $secret)
            Button("OK") { print("alert name: \(name) secret: \(secret.count) chars") }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enter your name") }
        .sheet(isPresented: $showInteractive) {
            Text("Background stays live").padding()
                .presentationDetents([.height(200), .medium])
                .presentationBackgroundInteraction(.enabled)
                .accessibilityIdentifier("interactive-text")
        }
        .sheet(isPresented: $showLocked, onDismiss: { print("locked dismissed") }) {
            LockedSheet()
        }
        .sheet(isPresented: $showForm) {
            Text("Form sized").frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("form-text")
                .modifier(FormSizing())
        }
        .fullScreenCover(isPresented: $showZoom) {
            ZoomCover(ns: ns)
        }
    }
}

struct LockedSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack { Text("Locked").accessibilityIdentifier("locked-text"); Button("Close") { dismiss() }.accessibilityIdentifier("locked-close") }
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
    }
}

struct ZoomCover: View {
    let ns: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Color.purple.ignoresSafeArea()
            .overlay { Button("Close") { dismiss() }.foregroundStyle(.white).accessibilityIdentifier("zoom-close") }
            .modifier(ZoomTransition(ns: ns))
    }
}

struct ZoomSource: ViewModifier {
    let ns: Namespace.ID
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.matchedTransitionSource(id: "tile", in: ns) } else { content }
    }
}
struct ZoomTransition: ViewModifier {
    let ns: Namespace.ID
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.navigationTransition(.zoom(sourceID: "tile", in: ns)) } else { content }
    }
}
struct FormSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.presentationSizing(.form) } else { content }
    }
}
